#!/usr/bin/env ruby

require './plugin'
Dir["../plugins/*.rb"].each { |f| require f }

require 'mumble-ruby'
require 'rubygems'
require 'ruby-mpd'
require 'thread'
require 'optparse'
require 'i18n'
require 'yaml'
require 'cgi'
require_relative "../helpers/conf.rb"


# copy@paste from https://gist.github.com/erskingardner/1124645#file-string_ext-rb
class String
  def to_bool
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    return false if self == false || self.nil? || self.empty? || self =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end

class MumbleMPD
  attr_reader :run

  def initialize
    @logging = []
    # load all plugins
    require './plugin'
    Dir["../plugins/*.rb"].each do |f|
      require f
      earlylog "OK: Plugin \"#{f}\" loaded."
    end
    @plugin = Array.new
    @set_private = Hash.new()
    #Initialize default values
    #Read config file if available
    begin
      Conf.load('../config/config.yml')
      earlylog "OK: Main configuration \"../config/config.yml\" loaded."
      Dir["../plugins/*.yml"].each do |f|
        Conf.load(f)
        earlylog "OK: Plugin configuration \"#{f}\" loaded."
      end
    rescue
      earlylog "Warning: Main configuration OR one OR more plugin configurations could not be loaded! Ignoring them and using default configuration."
    end
    OptionParser.new do |opts|
      opts.banner = "Usage: pluginbot.rb [options]"

      opts.on("--config=", "(Relative) path and filename to config") do |v|
      earlylog "OK: Parsing extra configuration file \"#{v}\" (--config parameter)"
        if File.exist? v
          begin
            Conf.load(v)
          rescue
            earlylog "Warning: Your config \"#{v}\" could not be loaded! Using default configuration."
          end
        else
          earlylog "Config path- and/or filename is wrong!"
          earlylog "used #{v}"
          earlylog "Config not loaded!"
        end
      end

      opts.on("--mumblehost=", "IP or Hostname of mumbleserver") do |v|
        Conf.svalue("mumble:host", v)
      end

      opts.on("--mumbleport=", "Port of Mumbleserver") do |v|
        Conf.svalue("mumble:port", v)
      end

      opts.on("--name=", "The Bot's Nickname") do |v|
        Conf.svalue("mumble:name", v)
      end

      opts.on("--userpass=", "Password if required for user") do |v|
        Conf.svalue("mumble:password", v)
      end

      opts.on("--targetchannel=", "Channel to be joined after connect") do |v|
        Conf.svalue("mumble:channel", v)
      end

      opts.on("--bitrate=", "Desired audio bitrate") do |v|
        Conf.svalue("mumble:bitrate", v.to_i)
      end

      opts.on("--fifo=", "Path to fifo") do |v|
        Conf.svalue("main:fifo", v.to_s)
      end

      opts.on("--mpdhost=", "MPD's Hostname") do |v|
        Conf.svalue("mpd:host", v)
      end

      opts.on("--mpdport=", "MPD's Port") do |v|
        Conf.svalue("mpd:port", v.to_i)
      end

      opts.on("--controllable=", "true if bot should be controlled from chatcommands") do |v|
        Conf.svalue("main:controlable", v.to_bool)
      end

      opts.on("--certdir=", "path to cert") do |v|
        Conf.svalue("main:certfolder", v)
      end
    end.parse!
    Conf.svalue("main:duckvol", 20) if !Conf.gvalue("main:duckvol").is_a?(Integer)
    @configured_settings = Conf.get.clone

    # now it is time to empty early log to logfile if it exist!
    logger "-------------------------Start Logging-------------------------------"
    @logging.each do |message|
      logger message
    end

  end

  def init_settings
    # set up language
    I18n.load_path = Dir["../i18n/**/*yml"]
    @configured_settings["language"] ||= "en"
    I18n.default_locale=@configured_settings["language"].to_sym
    @run = false
    @cli = Mumble::Client.new(Conf.gvalue("mumble:host"), Conf.gvalue("mumble:port")) do |conf|
      conf.username = Conf.gvalue("mumble:name")
      conf.password = Conf.gvalue("mumble:password")
      conf.bitrate = Conf.gvalue("mumble:bitrate").to_i
      if Conf.gvalue("mumble:use_vbr)").to_s.to_bool == true
        conf.vbr_rate = 1
      else
        conf.vbr_rate = 0
      end
      conf.ssl_cert_opts[:cert_dir] = File.expand_path(Conf.gvalue("main:certfolder"))
    end
  end

  def disconnect
    @cli.disconnect if @cli.connected?
  end

  def calc_overall_bandwidth(framelength, bitrate)
    ( 1000 / framelength.to_f * 320 ).to_i + bitrate
  end

  def get_overall_bandwidth
    #( 1000/ @cli.get_frame_length.to_f * 320 ).to_i + @cli.get_bitrate
    calc_overall_bandwidth(@cli.get_frame_length, @cli.get_bitrate)
  end

  def mumble_kill
    Thread.list.each do |t|
      if t["process"]
        logger "killing #{t["process"]} from user #{t["user"]}"
        t.kill
      end
    end
  end

  def mumble_start
    logger "OK: start connecting"
    @cli.on_server_config do |serverconfig|
      Conf.svalue("mumble:imagelength", serverconfig.image_message_length)
      Conf.svalue("mumble:messagelength", serverconfig.message_length)
      Conf.svalue("mumble:allow_html", serverconfig.allow_html)
    end

    @cli.on_suggest_config do |suggestconfig|
      Conf.svalue("mumble:version", suggestconfig.version)
      Conf.svalue("mumble:positional", suggestconfig.positional)
      Conf.svalue("mumble:push_to_talk", suggestconfig.push_to_talk)
    end
    @cli.connect
    max_connecting_time = 10
    while not @cli.connected? do
      sleep(0.5)
      logger "OK: Connecting to the server is still ongoing."
      max_connecting_time -= 1
      if max_connecting_time < 1
        logger "Error: Connection timed out"
        @cli.disconnect
        break
      end
    end
    if @cli.connected?
      logger "OK: Pluginbot successfully connected to \"#{Conf.gvalue("mumble:host")}:#{Conf.gvalue("mumble:port")}\"."
      begin
        @cli.join_channel(Conf.gvalue("mumble:channel"))
        logger "OK: Pluginbot entered configured channel \"#{Conf.gvalue("mumble:channel")}\"."
      rescue
        logger "ERROR: Can't join channel '#{Conf.gvalue("mumble:channel")}'! (#{$!})"
      end

      begin
        Thread.kill(@duckthread) if @ducktread != nil
      rescue
        logger "ERROR: [killduckthread] can't kill because #{$!}"
      end
      logger "OK: Starting Duckthread..."
      #Start duckthread
      @duckthread = Thread.new do
        Thread.current["user"]=Conf.gvalue("mumble:name")
        Thread.current["process"]="main (ducking)"
        while (true == true)
          while (@cli.player.volume != 100)
            @cli.player.volume += 2 if @cli.player.volume < 100
            sleep 0.02
          end
          Thread.stop
        end
      end
      logger "OK: Duckthread is spawned"
      begin
        @cli.set_comment('Mumble_Ruby_Pluginbot')
        Conf.svalue("main:display:comment:aviable", true)
      rescue NoMethodError
        logger "[displaycomment]#{$!}"
        Conf.svalue("main:display:comment:aviable", false)
      end
      begin
        @cli.set_avatar(IO.binread('../config/logo/logo.png'))
        Conf.svalue("main:display:avatar:aviable", true)
      rescue
        Conf.svalue("main:display:avatar:aviable", false)
      end
      logger "OK: Bot Avatar and Comment are set"
      # Register Callbacks
      @cli.on_user_state do |msg|
        handle_user_state_changes(msg)
      end

      @cli.on_text_message do |msg|
        handle_text_message(msg)
      end

      @cli.on_udp_tunnel do |udp|
        if Conf.gvalue("main:ducking") == true
            @cli.player.volume = ( Conf.gvalue("main:duckvol") |  0x1 ) - 1
          @duckthread.run if @duckthread.stop?
        end
      end
      logger "OK: Primary Bot Setup complete"
      @run = true

      #init all plugins
      #init = @settings.clone
      #init = Conf.get.clone       # Compatibility mode
      init = Hash.new           # New Method! (Breaks compatibility with old plugins)
      init[:cli] = @cli

      logger "OK: Initializing plugins..."
      Plugin.plugins.each do |plugin_class|
        @plugin << plugin_class.new
        logger "OK: Create Plugin Class: #{plugin_class}"
      end

      plugininitiation = Thread.new do
        Thread.current["user"]=Conf.gvalue("mumble:name")
        Thread.current["process"]="Init Plugins"
        maxcount = @plugin.length
        allok = 0
        while allok != @plugin.length do
          allok = 0
          @plugin.each do |plugin|
            @pluginname = plugin.class.name
            init = plugin.init(init)
            if plugin.name == plugin.class.name
              allok += 1
            end
          end
          maxcount -= 1
          break if maxcount <= 0
        end
        logger "Warning: Maybe not all plugins are functional!" if maxcount <= 0
      end

      now = Time.now
      while plugininitiation.status != false do
        sleep(0.5)
        if (Time.now - now) > 15
          logger "ERROR: Plugins take to long to init (last plugin start to init was '#{@pluginname}')"
          @run=false
          plugininitiation.terminate
        end
      end

      ## Enable Ticktimer Thread
      @ticktimer = Thread.new do
        Thread.current["user"]=Conf.gvalue("mumble:name")
        Thread.current["process"]="main (timertick)"
        timertick
      end
      logger "OK: Timertick is enabled"

    end
  end

  private

  def timertick
    ticktime = ( Conf.gvalue("main:timer:ticks") || 3600 )
    while (true==true)
      sleep(3600/ticktime)
      time = Time.now
      @plugin.each do |plugin|
      	begin
          plugin.ticks(time)
        rescue
          logger "ERROR: Plugin #{plugin.name} throws error in timertick (#{$!})"
        end
      end
    end
  end

  def handle_user_state_changes(msg)
    #msg.actor = session_id of user who did something on someone, if self done, both is the same.
    #msg.session = session_id of the target
  end

  def handle_text_message(msg)
    if msg.actor
      msg.username    = @cli.users[msg.actor].name
      msg.userhash    = @cli.users[msg.actor].hash.to_sym
      msg.user_id     = @cli.users[msg.actor].user_id
      msg.channel_id  = @cli.users[msg.actor].channel_id
      # else ignore text messages from the server
      # This is hacky because mumble uses -1 for user_id of unregistered users,
      # while mumble-ruby seems to just omit the value for unregistered users.
      # With this hacky thing commands from SuperUser are also being ignored.
      if msg.user_id.nil?
        msg_userid = -1
        sender_is_registered = false
      else
        msg_userid = msg.user_id
        sender_is_registered = true
      end

      logger "Debug: Got a message from \"#{msg.username}\" (user id: #{msg_userid}, session id: #{msg.actor}). Content: \"#{msg.message}\""
      # check if User is on a blacklist
      begin
        if Conf.gvalue("main:user:banned").has_key?("#{msg.userhash }")
          logger "Debug: User with userid \"#{msg_userid}\" is in blacklist! Ignoring him."
          sender_is_registered = false # If on blacklist handle user as if he was unregistered.
        end
      rescue
        #catch when user hasn't a hash. (not registerd)
      end

      # generating help message.
      # each command adds his own help
      help ="<br />"    # start with empty help
      # the help command should be the last command in this function

      #FIXME
      #msg.message.gsub!(/(<[^<^>]*>)/, "") #Strip html tags. #BEFORE doing this we need to ensure that no plugin needs the html source code. For example youtube plugin needs them...
      msg.message.strip! #remove leading and trailing whitespaces
      msg.message.gsub!(/\s/," ") #replace all carriage return and newline in message to spaces

      #blacklisted_commands = @settings["main"]["blacklisted_commands"]
      blacklisted_commands = Conf.gvalue("main:blacklisted_commands")

      #if (sender_is_registered == true) || (@settings["main"]["control"]["message"]["registered_only"] == false)
      if (sender_is_registered == true) || (Conf.gvalue("main:control:message:registered_only") == false)
        #Check whether message is a private one or was sent to the channel.
        # Private message looks like this:   <Hashie::Mash actor=54 message="#help" session=[119]>
        # Channel message:                   <Hashie::Mash actor=54 channel_id=[530] message="#help">
        # Channel messages don't have a session, so skip them
        if ( msg.session ) || ( Conf.gvalue("main:control:message:private_only") != true )
          if Conf.gvalue("main:controllable") == true
            if msg.message.start_with?("#{Conf.gvalue("main:control:string")}") && msg.message.length > Conf.gvalue("main:control:string").length #Check whether we have a command after the controlstring.
              begin
                message = msg.message.split(Conf.gvalue("main:control:string"))[1 .. -1].join()
              rescue
                message = "help"  # FIXME Set 'help' if the given command from user caused an exception.
              end

              # FIXME Better is:
              # if blacklisted_commands.include?(current_command)
              # But we need the current_command then. We do have only the complete
              # message currently.

              for command in blacklisted_commands.split(" ") do
                if message.start_with?(command)
                  @cli.text_user(msg.actor, I18n.t('command_blacklisted'))
                  return
                end
              end

              @plugin.each do |plugin|
                begin
                  plugin.handle_chat(msg, message) if plugin.name != "false"
                rescue
                  logger "ERROR: Plugin #{plugin.name} throws error in handle_chat (#{$!})"
                end
              end

              if message == 'about'
                @cli.text_user(msg.actor, I18n.t('about'))
              end

              # This functions need superuser permission
              if !Conf.gvalue("main:user:superuser").nil?
                if Conf.gvalue("main:user:superuser").has_key?("#{msg.userhash }")
                  # Show settings
                  if  message == 'settings'
                    @cli.text_user(msg.actor, hash_to_table(Conf.get))
                  end
                  # Modify settings
                  if message.split[0] == 'set'
                    setting = message.split[1].split('=',2)
                    Conf.svalue(setting[0], setting[1])
                  end
                  # Reset settings to default value
                  if message == 'reset'
                    @cli.text_user(msg.actor, hash_to_table(@configured_settings))
                    Conf.overwrite(@configured_settings) if Conf.gvalue("main:user:bound") == msg_userid
                  end
                end
              end

              if message.split(" ")[0] == 'showhash'
                if @cli.find_user(message.split[1..-1].join(" "))
                  @cli.text_user(msg.actor, "#{@cli.find_user(message.split[1..-1].join(" ")).hash.to_sym}:  #{message.split[1..-1].join(" ")}")
                else
                  @cli.text_user(msg.actor, "#{msg.userhash}")
                end
              end

              if message == 'bind'
                Conf.svalue("main:user:bound", "#{msg.userhash}") if Conf.gvalue("main:user:bound") == nil
              end

              if message == 'unbind'
                Conf.svalue("main:user:bound", nil) if Conf.gvalue("main:user:bound") == "#{msg.userhash}"
              end



              if message == 'register'
                if Conf.gvalue("main:user:bound") == msg_userid
                  @cli.me.register
                end
              end

              if message.split(" ")[0] == 'blacklist'
                if Conf.gvalue("main:user:bound") == msg_userid
                  if @cli.find_user(message.split[1..-1].join(" "))
                    Conf.svalue("main:user:banned:#{@cli.find_user(message.split[1..-1].join(" ")).hash.to_sym}", "#{message.split[1..-1].join(" ")}")
                    @cli.text_user(msg.actor, I18n.t("ban.active"))
                    @cli.text_user(msg.actor, "main: user: banned: #{@cli.find_user(message.split[1..-1].join(" ")).hash.to_sym}:  #{message.split[1..-1].join(" ")}")
                  else
                    @cli.text_user(msg.actor, I18n.t("user.not.found", :user => message.split[1..-1].join(" ")))
                  end
                end
              end

              if message == 'ducking'
                Conf.svalue("main:ducking", !Conf.gvalue("main:ducking"))
                if Conf.gvalue("main:ducking") == false
                  @cli.text_user(msg.actor, I18n.t("ducking._off"))
                else
                  @cli.text_user(msg.actor, I18n.t("ducking._on"))
                end
              end

              if message == 'duckvol'
                @cli.text_user(msg.actor, I18n.t("ducking.volume.settings", :volume_relative => Conf.gvalue("main:duckvol")))
                if Conf.gvalue("main:ducking") == false
                  @cli.text_user(msg.actor, I18n.t("ducking._off"))
                else
                  @cli.text_user(msg.actor, I18n.t("ducking._on"))
                end
              end

              if message.match(/^duckvol [0-9]{1,3}$/)
                volume = message.match(/^duckvol ([0-9]{1,3})$/)[1].to_i
                if (volume >=0 ) && (volume <= 100)
                  Conf.svalue("main:duckvol", volume)
                  @cli.text_user(msg.actor, I18n.t("ducking.volume.set", :volume_relative => volume))
                else
                  @cli.text_user(msg.actor, I18n.t("ducking.volume.out_of_range"))
                end
              end

              if message == 'bitrate'
                begin
                  @cli.text_user(msg.actor, I18n.t("bitrate.set", :bitrate => @cli.get_bitrate.to_s))
                rescue
                  @cli.text_user(msg.actor, "bitrate.error")
                end
              end

              if message.match(/^bitrate [0-9]{1,3}$/)
                bitrate = message.match(/^bitrate ([0-9]{1,3})$/)[1].to_i * 1000
                begin
                  @cli.set_bitrate(bitrate)
                  @cli.text_user(msg.actor, I18n.t("bitrate.set", :bitrate => @cli.get_bitrate))
                  @cli.text_user(msg.actor, I18n.t("bandwidth.set", :bandwidth => get_overall_bandwidth))
                rescue
                  @cli.text_user(msg.actor, I18n.t("bitrate.error"))
                end
              end

              if message == 'framesize'
                begin
                  @cli.text_user(msg.actor, I18n.t("framesize.set", :framesize => @cli.get_frame_length.to_s))
                rescue
                  @cli.text_user(msg.actor, I18n.t("framesize.error"))
                end
              end

              if message.match(/^framesize [0-9]{1,2}$/)
                framelength = message.match(/^framesize ([0-9]{1,2})$/)[1].to_i
                begin
                  @cli.set_frame_length(framelength)
                  @cli.text_user(msg.actor, I18n.t("framesize.set", :framesize => @cli.get_frame_length.to_s))
                  @cli.text_user(msg.actor, I18n.t("bandwidth.set", :bandwidth => get_overall_bandwidth))
                  @cli.text_user(msg.actor, I18n.t("bandwidth.max", :bandwidth => @cli.max_bandwidth))
                rescue
                  @cli.text_user(msg.actor, I18n.t("bitrate.error"))
                end
              end

              if message == 'bandwidth'
                begin
                   @cli.text_user(msg.actor, I18n.t("bandwidth.settings", :overall => get_overall_bandwidth, :audio => @cli.get_bitrate.to_s , :framesize => @cli.get_frame_length.to_s))
                rescue
                  @cli.text_user(msg.actor, "bitrate.error")
                end
              end

              if message == 'plugins'
                help = I18n.t("plugins.loaded._shead")
                #Generate name list
                pluginnames = []
                @plugin.each do |plugin|
                  pluginnames << plugin.name if plugin.name == plugin.class.name
                end
                #Sort name list
                pluginnames.sort!
                #Push it to help list
                pluginnames.each do |name|
                  help << name + "<br />"
                end
                help << I18n.t("plugins.loaded._ehead")

                help << I18n.t("plugins.general_help", :control => Conf.gvalue("main:control:string"))
                @cli.text_user(msg.actor, help)
              end

              # early in development, not documented now until it works :)
              if message == "jobs"
                output = ""
                Thread.list.each do |t|
                  if t["process"]
                    output << I18n.t("jobs.status", :process => t["process"], :status => t.status.to_s, :name=> t["user"])
                  end
                end
                @cli.text_user(msg.actor, output)
              end

              if message == 'internals'
                @cli.text_user(msg.actor, I18n.t("help.internal", :cc => Conf.gvalue("main:control:string")))
              end

              if message.split[0] == 'help'
                if message.split[1] == 'all' #Send help texts of all plugins.
                    @plugin.each do |plugin|
                        #help = plugin.help(help.to_s)
                        help = plugin.help('')
                        @cli.text_user(msg.actor, help)
                    end
                elsif message.split[1] #Send help for a specific plugin.
                  @plugin.each do |plugin|
                    help = plugin.help('') if plugin.name.upcase == message.split[1].upcase
                  end

                  @cli.text_user(msg.actor, help)
                else #Send default help text.
                  @cli.text_user(msg.actor, I18n.t("help.default", :cc=> Conf.gvalue("main:control:string")))
                end
              end
            end
          end
        else
          logger "DEBUG: Not listening because [:listen_to_private_message_only] is true and message was sent to channel."
        end
      else
        logger "DEBUG: Not listening because [:listen_to_registered_users_only] is true and sender is unregistered or on a blacklist."
      end
    end
  end

  def hash_to_table(hash)
    if !hash.kind_of?(Hash)
      to_ret_val = CGI.escapeHTML(hash.to_s)
      return "<i>#{to_ret_val}</i> (#{hash.class})"
    end
    out = "<ul>"
    hash.each do |key, value|
      Hash === value ? out << "<li>" : out << "<li>"
      out << "#{key}: " << "#{hash_to_table(value)}"
      Hash === value ? out << "</li>" : out << "</li>"
    end
    out << "</ul>"
    return out
  end

  def earlylog(message)
    @logging.push message
    puts message
  end

  def logger(message)
    if Conf.gvalue("debug")
      logline="#{Time.new.to_s} : #{message}\n"
      if Conf.gvalue("main:logfile") == nil
        puts logline.chomp
      else
        written = IO.write(Conf.gvalue("main:logfile"), logline, mode: 'a')
        if written != logline.length
          puts "ERROR: Logfile (#{Conf.gvalue("main:logfile")}) is not writeable, logging to stdout instead"
		  puts logline.chomp
      Conf.svalue("main:logfile", nil)
		end
      end
    end
  end
end

#
# => planned for remove
#
client = MumbleMPD.new
client.init_settings

puts "OK: Pluginbot is starting..."
begin
  puts "OK: Pluginbot is running."
  client.mumble_start
rescue
  puts "ERROR: Pluginbot could not start. (#{$!})"
  puts $!
  puts $@
end

sleep 3
begin
  while client.run == true
      sleep 0.5
  end
rescue
  puts "ERROR: An error occurred: #{$!}"
  puts "ERROR: Backtrace: #{$@}"
end

client.disconnect
client.mumble_kill
Thread.list.each do |t|
  t.kill if t!=Thread.main
end
#
# => planned for remove
#
