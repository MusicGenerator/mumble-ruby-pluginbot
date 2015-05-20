#!/usr/bin/env ruby

require './plugin'
Dir["./plugins/*.rb"].each { |f| require f }


require 'mumble-ruby'
require 'rubygems'
require 'ruby-mpd'
require 'thread'
require 'optparse'


# copy@paste from https://gist.github.com/erskingardner/1124645#file-string_ext-rb
class String
    def to_bool
        return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
        return false if self == false || self.blank? || self =~ (/(false|f|no|n|0)$/i)
        raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
    end
end

class MumbleMPD
        attr_reader :run
        Cvolume =      0x01 #send message when volume change
        Cupdating_db = 0x02 #send message when database update
        Crandom =      0x04 #send message when random mode changed
        Csingle =      0x08 #send message when single mode changed
        Cxfade =       0x10 #send message when crossfading changed
        Cconsume =     0x20 #send message when consume-mode changed
        Crepeat =      0x40 #send message when repeat-mode changed
        Cstate =       0x80 #send message when state changes

    def initialize
        # load all plugins
        require './plugin'
        Dir["./plugins/*.rb"].each do |f| 
            require f 
            puts "Plugin #{f} geladen."
        end

        @settings = Hash.new()
        #Initialize default values
        @priv_notify = {}

        @template_if_comment_enabled = "<b>Artist: </b>%s<br />"\
                            + "<b>Title: </b>%s<br />" \
                            + "<b>Album: </b>%s<br /><br />" \
                            + "<b>Write %shelp to me, to get a list of my commands!"
        @template_if_comment_disabled = "<b>Artist: </b>DISABLED<br />"\
                            + "<b>Title: </b>DISABLED<br />" \
                            + "<b>Album: </b>DISABLED<br /><br />" \
                            + "<b>Write %shelp to me, to get a list of my commands!"
        #Read config file if available 
        begin
            require_relative 'pluginbot_conf.rb'
            ext_config()
        rescue
            puts "Config could not be loaded! Using default configuration."
        end

        OptionParser.new do |opts|
            opts.banner = "Usage: superbot_2.rb [options]"

            opts.on("--mumblehost=", "IP or Hostname of mumbleserver") do |v|
                @settings[:mumbleserver_host] = v
            end

            opts.on("--mumbleport=", "Port of Mumbleserver") do |v|
                @settings[:mumbleserver_port] = v
            end

            opts.on("--name=", "The Bot's Nickname") do |v|
                @settings[:mumbleserver_username] = v
            end

            opts.on("--userpass=", "Password if required for user") do |v|
                @settings[:mumbleserver_userpassword] = v
            end

            opts.on("--targetchannel=", "Channel to be joined after connect") do |v|
                @settings[:mumbleserver_targetchannel] = v
            end

            opts.on("--bitrate=", "Desired audio bitrate") do |v|
                @settings[:quality_bitrate] = v.to_i
            end

            opts.on("--fifo=", "Path to fifo") do |v|
                @settings[:mpd_fifopath] = v.to_s
            end

            opts.on("--mpdhost=", "MPD's Hostname") do |v|
                @settings[:mpd_host] = v
            end

            opts.on("--mpdport=", "MPD's Port") do |v|
                @settings[:mpd_port] = v.to_i
            end

            opts.on("--controllable=", "true if bot should be controlled from chatcommands") do |v|
                @settings[:controllable] = v.to_bool
            end

            opts.on("--certdir=", "path to cert") do |v|
                @settings[:certdirectory] = v
            end
        end.parse! 
        @configured_settings = @settings.clone 
    end
    
    def init_settings
        @mpd = nil
        @cli = nil

        @mpd = MPD.new @settings[:mpd_host], @settings[:mpd_port].to_i

        @cli = Mumble::Client.new(@settings[:mumbleserver_host], @settings[:mumbleserver_port]) do |conf|
            conf.username = @settings[:mumbleserver_username]
            conf.password = @settings[:mumbleserver_userpassword]
            conf.bitrate = @settings[:quality_bitrate].to_i
            conf.vbr_rate = @settings[:use_vbr]
            conf.ssl_cert_opts[:cert_dir] = File.expand_path(@settings[:certdirectory])
        end
    end
    
    def mumble_start

        @cli.connect
         while not @cli.connected? do
            sleep(0.5)
            puts "Connecting to the server is still ongoing." if @settings[:debug]
        end
        begin
            @cli.join_channel(@settings[:mumbleserver_targetchannel])
        rescue
            puts "[joincannel]#{$1} Can't join #{@settings[:mumbleserver_targetchannel]}!" if @settings[:debug]
        end

        begin
            Thread.kill(@duckthread)
        rescue
            puts "[killduckthread] can't kill because #{$1}" if @settings[:debug]
        end
        
        #Start duckthread
        @duckthread = Thread.new do
            while (true == true)
                while (@cli.player.volume != 100)
                    if ((Time.now - @lastaudio) < 0.1) then 
                        @cli.player.volume = 20
                    else
                        @cli.player.volume += 2 if @cli.player.volume < 100
                    end
                    sleep 0.02
                end
                Thread.stop
            end
        end

        begin
            @cli.set_comment("")
            @settings[:set_comment_available] = true
        rescue NoMethodError
            puts "[displaycomment]#{$!}" if @settings[:debug]
            @settings[:set_comment_available] = false 
        end

        @cli.on_user_state do |msg|
            handle_user_state_changes(msg)
        end

        @cli.on_text_message do |msg|
            handle_text_message(msg)
        end

        @cli.on_udp_tunnel do |udp|
            @lastaudio = Time.now
            @cli.player.volume = 20 if @settings[:ducking] == true
            @duckthread.run if @duckthread.stop?
        end

        @lastaudio = Time.now

        @run = true
        main = Thread.new do
            while (@run == true)
                sleep 1
                current = @mpd.current_song if @mpd.connected?
                if not current.nil? #Would crash if playlist was empty.
                    lastcurrent = current if lastcurrent.nil? 
                    if lastcurrent.title != current.title 
                        if @settings[:use_comment_for_status_display] == true && @settings[:set_comment_available] == true
                            begin
                                if File.exist?("../music/download/"+current.title.to_s+".jpg")
                                    image = @cli.get_imgmsg("../music/download/"+current.title+".jpg")
                                else
                                    image = @settings[:logo]
                                end
                                output = "<br />" + @template_if_comment_enabled % [current.artist, current.title, current.album,@settings[:controlstring]]
                                @cli.set_comment(image+output)
                            rescue NoMethodError
                                if @settings[:debug]
                                    puts "#{$!}"
                                end
                            end
                        else
                            if current.artist.nil? && current.title.nil? && current.album.nil?
                                @cli.text_channel(@cli.me.current_channel, "#{current.file}") if @settings[:chan_notify] && 0x80
                            else
                                @cli.text_channel(@cli.me.current_channel, "#{current.artist} - #{current.title} (#{current.album})") if (@settings[:chan_notify] && 0x80) != 0
                            end
                        end
                        lastcurrent = current
                        puts "[displayinfo] update" if @settings[:debug]
                    end
                end
            end
        end
        initialize_mpdcallbacks
        @cli.player.stream_named_pipe(@settings[:mpd_fifopath]) 
        @mpd.connect true #without true bot does not @cli.text_channel messages other than for !status

        #init all plugins
        init = @settings.clone
        init[:mpd] = @mpd
        init[:cli] = @cli
        @plugin = Array.new
        Plugin.plugins.each do |plugin_class|
            @plugin << plugin_class.new
        end

        @plugin.each do |plugin|
            plugin.init(init)
            puts "Init plugin #{plugin}"
        end
    end
    
    def initialize_mpdcallbacks
        @mpd.on :volume do |volume|
            sendmessage("Volume was set to: #{volume}%." , 0x01)
        end
        
        @mpd.on :error do |error|
            @cli.text_channel(@cli.me.current_channel, "<span style='color:red;font-weight:bold;>An error occured: #{error}.</span>") 
        end
        
        @mpd.on :updating_db do |jobid|
            @cli.text_channel(@cli.me.current_channel, "I am running a database update just now ... new songs :)<br />My job id is: #{jobid}.") if (@settings[:chan_notify] & 0x02) != 0
        end
        
        @mpd.on :random do |random|
            if random
                random = "On"
            else
                random = "Off"
            end
            @cli.text_channel(@cli.me.current_channel, "Random mode is now: #{random}.") if (@settings[:chan_notify] & 0x04) != 0
        end
        
        @mpd.on :state  do |state|
            if @settings[:chan_notify] & 0x80 != 0 then
                @cli.text_channel(@cli.me.current_channel, "Music paused.") if  state == :pause 
                @cli.text_channel(@cli.me.current_channel, "Music stopped.") if state == :stop  
                @cli.text_channel(@cli.me.current_channel, "Music start playing.") if state == :play 
            end
        end
        
        @mpd.on :single do |single|
            if single
                single = "On"
            else
                single = "Off"
            end
            @cli.text_channel(@cli.me.current_channel, "Single mode is now: #{single}.") if (@settings[:chan_notify] & 0x08) != 0
        end
        
        @mpd.on :consume do |consume|
            if consume
                consume = "On"
            else
                consume = "Off"
            end

            @cli.text_channel(@cli.me.current_channel, "Consume mode is now: #{consume}.") if (@settings[:chan_notify] & 0x10) != 0
        end
        
        @mpd.on :xfade do |xfade|
            if xfade.to_i == 0
                xfade = "Off"
                @cli.text_channel(@cli.me.current_channel, "Crossfade is now: #{xfade}.") if (@settings[:chan_notify] & 0x20) != 0
            else
                @cli.text_channel(@cli.me.current_channel, "Crossfade time (in seconds) is now: #{xfade}.") if (@settings[:chan_notify] & 0x20) != 0 
            end
        end
        
        @mpd.on :repeat do |repeat|
            if repeat
                repeat = "On"
            else
                repeat = "Off"
            end
            @cli.text_channel(@cli.me.current_channel, "Repeat mode is now: #{repeat}.") if (@settings[:chan_notify] & 0x40) != 0
        end
        
        @mpd.on :song do |current|
            if not current.nil? #Would crash if playlist was empty.
                if @settings[:use_comment_for_status_display] == true && @settings[:set_comment_available] == true
                    begin
                        if File.exist?("../music/download/"+current.title.to_s+".jpg")
                            image = @cli.get_imgmsg("../music/download/"+current.title+".jpg")
                        else
                            image = @settings[:logo]
                        end
                        output = "<br />" + @template_if_comment_enabled % [current.artist, current.title, current.album,@settings[:controlstring]]
                        @cli.set_comment(image+output)
                    rescue NoMethodError
                        if @settings[:debug]
                            puts "#{$!}"
                        end
                    end
                else
                    if current.artist.nil? && current.title.nil? && current.album.nil?
                        @cli.text_channel(@cli.me.current_channel, "#{current.file}") if @settings[:chan_notify] && 0x80
                    else
                        @cli.text_channel(@cli.me.current_channel, "#{current.artist} - #{current.title} (#{current.album})") if (@settings[:chan_notify] && 0x80) != 0
                    end
                end
            end
        end
    end
    
    def handle_user_state_changes(msg)
        #msg.actor = session_id of user who did something on someone, if self done, both is the same.
        #msg.session = session_id of the target

        msg_target = @cli.users[msg.session]
        
        if msg_target.user_id.nil?
            msg_userid = -1
            sender_is_registered = false
        else
            msg_userid = msg_target.user_id
            sender_is_registered = true
        end
        if @cli.me.current_channel != nil               
            if @cli.me.current_channel.channel_id == msg_target.channel_id
                if (@settings[:stop_on_unregistered_users] == true && sender_is_registered == false)
                    @mpd.stop
                    @cli.text_channel(@cli.me.current_channel, "<span style='color:red;'>An unregistered user currently joined or is acting in our channel. I stopped the music.</span>")
                end
            end
        end
    end
    
    def handle_text_message(msg)
        if msg.actor.nil?
            ##next #Ignore text messages from the server
            return
        end
    
        #Some of the next two information we may need later...
        msg_sender = @cli.users[msg.actor]
        
        #This is hacky because mumble uses -1 for user_id of unregistered users,
        # while mumble-ruby seems to just omit the value for unregistered users.
        # With this hacky thing commands from SuperUser are also being ignored.
        if msg_sender.user_id.nil?
            msg_userid = -1
            sender_is_registered = false
        else
            msg_userid = msg_sender.user_id
            sender_is_registered = true
        end

        # generating help message.
        # each command adds his own help
        help ="<br />"    # start with empty help
        # the help command should be the last command in this function
        cc = @settings[:controlstring]
                
        help += "<b>superpassword+restart</b> will restart the bot.<br />"
        if msg.message == @superpassword+"restart"
            @settings = @configured_settings.clone
            @cli.text_channel(@cli.me.current_channel,@superanswer);
            @run = false
            @cli.disconnect
        end

        help += "<b>superpassword+reset</b> will reset variables to start values.<br />"
        if msg.message == @superpassword+"reset"
            @settings = @configured_settings.clone
            @cli.text_channel(@cli.me.current_channel,@superanswer);
        end

        if @settings[:listen_to_registered_users_only] == true
            if sender_is_registered == false
                if @settings[:debug]
                    puts "Debug: Not listening because @settings[:listen_to_registered_users_only] is true and sender is unregistered."
                end
                
                #next
                return
            end
        end    
        
        #Check whether message is a private one or was sent to the channel.
        # Private message looks like this:   <Hashie::Mash actor=54 message="#help" session=[119]>
        # Channel message:                   <Hashie::Mash actor=54 channel_id=[530] message="#help">
        # Channel messages don't have a session, so skip them
        if not msg.session
            if @settings[:listen_to_private_message_only] == true
                if @settings[:debug]
                    puts "Debug: Not listening because @settings[:listen_to_private_message_only] is true and message was sent to channel."
                end
                #next
                return
            end
        end
        if @settings[:controllable] == true
            if msg.message.start_with?("#{@settings[:controlstring]}") && msg.message.length >@settings[:controlstring].length #Check whether we have a command after the controlstring.
                message = msg.message.split(@settings[:controlstring])[1] #Remove@settings[:controlstring]
                @plugin.each do |plugin|
                    plugin.handle_chat(msg, message)
                end
                
                help += "<b>#{cc}settings</b> display current settings.<br />"
                if message == 'settings' 
                    out = "<table>"
                    @settings.each do |key, value|
                        out += "<tr><td>#{key}</td><td>#{value}</td></tr>"
                    end
                    out += "</table>"
                    @cli.text_user(msg.actor, out)    
                end

                help += "<b>#{cc}set <i>variable=value</i></b> Set variable to value.<br />"
                if message.split[0] == 'set' 
                    if !@settings[:need_binding] || @settings[:boundto]==msg_userid
                        setting = message.split('=',2)
                        @settings[setting[0].split[1].to_sym] = setting[1] if setting[0].split[1] != nil
                    end
                end

                help += "<b>#{cc}bind</b> Bind Bot to a user. (some functions will only do if bot is bound).<br />"
                if message == 'bind'
                    @settings[:boundto] = msg_userid if @settings[:boundto] == "nobody"
                end        
                
                help += "<b>#{cc}unbind</b> Unbind Bot.<br />"
                if message == 'unbind'
                    @settings[:boundto] = "nobody" if @settings[:boundto] == msg_userid
                end
                
                help += "<b>#{cc}reset</b> Reset variables to default value. Needs binding!<br />"
                if message == 'reset' 
                    @settings = @configured_settings.clone if @settings[:boundto] == msg_userid
                end
                
                help += "<b>#{cc}restart</b> Restart Bot. Needs binding.<br />"
                if message == 'restart'
                    if @settings[:boundto] == msg_userid
                        @run=false
                        @cli.disconnect
                    end
                end

                help += "<b>#{cc}displayinfo</b> Toggles Infodisplay from comment to message and back.<br />"
                if message == 'displayinfo'
                    begin
                        if @settings[:use_comment_for_status_display] == true
                            @settings[:use_comment_for_status_display] = false
                            @cli.text_user(msg.actor, "Output is now \"Channel\"")
                            @cli.set_comment(@template_if_comment_disabled % [@controlstring])
                        else
                            @settings[:use_comment_for_status_display] = true
                            @cli.text_user(msg.actor, "Output is now \"Comment\"")
                            @cli.set_comment(@template_if_comment_enabled)
                        end
                    rescue NoMethodError
                        if @settings[:debug]
                            puts "#{$!}"
                        end
                    end
                end

                help += "<b>#{cc}ducking</b> toggle voice ducking on/off.<br />"
                if message == 'ducking' 
                   @settings[:ducking] = !@settings[:ducking]
                   if @settings[:ducking] == false 
                        @cli.text_user(msg.actor, "Music ducking is off.")
                    else
                        @cli.text_user(msg.actor, "Music ducking is on.")
                    end
                end

                @priv_notify[msg.actor] = 0 if @priv_notify[msg.actor].nil?
                if message[2] == '#'
                    message.split.each do |command|
                        case command
                        when "#volume"
                            add = Cvolume
                        when "#update"
                            add = Cupdating_db
                        when "#random"
                            add = Crandom
                        when "#single"
                            add = Csingle
                        when "#xfade"
                            add = Cxfade
                        when "#consume"
                            add = Cconsume
                        when "#repeat"
                            add = Crepeat
                        when "#state"
                            add = Cstate
                        else
                            add = 0
                        end
                        @priv_notify[msg.actor] |= add if message[0] == '+' 
                        @priv_notify[msg.actor] &= ~add if message[0] == '-' 
                    end
                end
                if message == '*' && !@priv_notify[msg.actor].nil?
                    send = "You listen to following MPD-Channels:"
                    send += " #volume" if (@priv_notify[msg.actor] & Cvolume) > 0
                    send += " #update" if (@priv_notify[msg.actor] & Cupdating_db) > 0
                    send += " #random" if (@priv_notify[msg.actor] & Crandom) > 0
                    send += " #single" if (@priv_notify[msg.actor] & Csingle) > 0
                    send += " #xfade" if (@priv_notify[msg.actor] & Cxfade) > 0
                    send += " #repeat" if (@priv_notify[msg.actor] & Crepeat) > 0
                    send += " #state" if (@priv_notify[msg.actor] & Cstate) > 0
                    send += "."
                    @cli.text_user(msg.actor, send)
                end

                help += "<b>#{cc}help</b> Get this list :).<br />"
                if message == 'help'
                    @cli.text_user(msg.actor, help)
                end
           end
        end
    end
    
    def sendmessage (message, messagetype)
        @cli.text_channel(@cli.me.current_channel, message) if ( @settings[:chan_notify] & messagetype) != 0
        if !@priv_notify.nil?
            @priv_notify.each do |user, notify| 
                begin
                    @cli.text_user(user,message) if ( notify & messagetype) != 0
                rescue
                
                end
            end
        end
    end
end

puts "pluginbot is starting..." 
client = MumbleMPD.new
while true == true
    client.init_settings
    client.mumble_start    
    sleep 3
    while client.run == true
        sleep 0.5
    end
    sleep 0.5
end

