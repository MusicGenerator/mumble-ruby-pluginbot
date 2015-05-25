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

    def initialize
        # load all plugins
        require './plugin'
        Dir["./plugins/*.rb"].each do |f| 
            require f 
            puts "Plugin #{f} geladen."
        end
        @plugin = Array.new

        @settings = Hash.new()
        #Initialize default values

        #Read config file if available 
        begin
            require_relative 'pluginbot_conf.rb'
            ext_config()
        rescue
            puts "Config could not be loaded! Using default configuration."
        end

        OptionParser.new do |opts|
            opts.banner = "Usage: pluginbot.rb [options]"

            opts.on("--config=", "(Relative) path and filename to config") do |v|
                if File.exist? v
                    require_relative v
                    begin
                        require_relative v
                        ext_config()
                    rescue
                        puts "Your config could not be loaded!"
                    end
                else
                    puts "Config path- and/or filename is wrong!"
                    puts "Config not loaded!"
                end
            end
            
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
        @cli = nil
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
            puts "[killduckthread] can't kill because #{$!}" if @settings[:debug]
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
        @cli.player.stream_named_pipe(@settings[:mpd_fifopath]) 

        #init all plugins
        init = @settings.clone
        init[:cli] = @cli
        puts "initplugins"
        Plugin.plugins.each do |plugin_class|
            @plugin << plugin_class.new
        end

        maxcount = @plugin.length 
        allok = 0
        while allok != @plugin.length do
            allok = 0
            @plugin.each do |plugin|
                init = plugin.init(init)
                if plugin.name != "false"
                    allok += 1
                end
            end
            maxcount -= 1
            break if maxcount <= 0 
        end
        puts "maybe not all plugin functional!" if maxcount <= 0
    end
    
    def handle_user_state_changes(msg)
        #msg.actor = session_id of user who did something on someone, if self done, both is the same.
        #msg.session = session_id of the target
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
        
        help = "<br /><span style='color:red;'><b>Internal commands</b></span><br />"
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


                help += "<b>#{cc}ducking</b> toggle voice ducking on/off.<br />"
                if message == 'ducking' 
                   @settings[:ducking] = !@settings[:ducking]
                   if @settings[:ducking] == false 
                        @cli.text_user(msg.actor, "Music ducking is off.")
                    else
                        @cli.text_user(msg.actor, "Music ducking is on.")
                    end
                end

                help += "<b>#{cc}help <i>pluginname</i></b> Get help for plugin.<br />"
                if message.split[0] == 'help'
                    if message.split[1]=='all'
                        @plugin.each do |plugin|
                            help = plugin.help(help.to_s)
                        end
                    end
                    if message.split[1]!=nil
                        @plugin.each do |plugin|
                          help = plugin.help('') if plugin.name.upcase == message.split[1].upcase
                        end
                    else
                        help += "<span style='color:red;'>Loaded plugins:<br /><b>"
                        @plugin.each do |plugin|
                            help += plugin.name + "<br />"
                        end
                        help += "</b></span>"
                    end
                    
                    @cli.text_user(msg.actor, help)
                end
           end
        end
    end
    
 end

puts "pluginbot is starting..." 
client = MumbleMPD.new
while true == true
    client.init_settings
    puts "start"
    client.mumble_start    
    sleep 3
    while client.run == true
        sleep 0.5
    end
    sleep 0.5
end

