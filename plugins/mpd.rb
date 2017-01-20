# a pluginbot plugin
#require_relative '../helpers/MessageParser.rb'

class Mpd < Plugin

  def init(init)
    super
    @@bot = init
    #init default template
    #@infotemplate = "send <b>#{Conf.gvalue("main:control:string")}help</b> or <b>#{Conf.gvalue("main:control:string")}about</b> for more information about me."

    @infotemplate = I18n.t("about_control", :controlstring => Conf.gvalue("main:control:string"))

    if ( @@bot[:messages] ) && ( @@bot[:mpd].nil? ) then
      logger("INFO: INIT plugin #{self.class.name}.")
      @@bot[:mpd] = MPD.new Conf.gvalue("plugin:mpd:host"), Conf.gvalue("plugin:mpd:port").to_i

      @@bot[:mpd].on :volume do |volume|
        @@bot[:messages].sendmessage("Volume was set to: #{volume}%." , 0x01)
      end

      @@bot[:mpd].on :error do |error|
        channelmessage( "<span style='color:red;font-weight:bold;>An error occured: #{error}.</span>")
      end

      @@bot[:mpd].on :updating_db do |jobid|
        channelmessage( "I am running a database update just now ... new songs :)<br>My job id is: #{jobid}.") if Conf.gvalue("main:channel_notify").to_i & 0x02  != 0
      end

      @@bot[:mpd].on :random do |random|
        if random
          random = "On"
        else
          random = "Off"
        end
        channelmessage( "Random mode is now: #{random}.") if Conf.gvalue("main:channel_notify").to_i & 0x04 != 0
      end

      @@bot[:mpd].on :state  do |state|
        if Conf.gvalue("main:channel_notify").to_i & 0x80 != 0 then
          channelmessage( "Music paused.") if  state == :pause
          channelmessage( "Music stopped.") if state == :stop
          channelmessage( "Music start playing.") if state == :play
        end
      end

      @@bot[:mpd].on :single do |single|
        if single
          single = "On"
        else
          single = "Off"
        end
        channelmessage( "Single mode is now: #{single}.") if (Conf.gvalue("main:channel_notify").to_i & 0x08) != 0
      end

      @@bot[:mpd].on :consume do |consume|
        if consume
          consume = "On"
        else
          consume = "Off"
        end

        channelmessage( "Consume mode is now: #{consume}.") if (Conf.gvalue("main:channel_notify").to_i & 0x10) != 0
      end

      @@bot[:mpd].on :xfade do |xfade|
        if xfade.to_i == 0
          xfade = "Off"
          channelmessage( "Crossfade is now: #{xfade}.") if (Conf.gvalue("main:channel_notify").to_i & 0x20) != 0
        else
          channelmessage( "Crossfade time (in seconds) is now: #{xfade}.") if (Conf.gvalue("main:channel_notify").to_i & 0x20) != 0
        end
      end

      @@bot[:mpd].on :repeat do |repeat|
        if repeat
          repeat = "On"
        else
          repeat = "Off"
        end
        channelmessage( "Repeat mode is now: #{repeat}.") if (Conf.gvalue("main:channel_notify").to_i & 0x40) != 0
      end

      @@bot[:mpd].on :song do |current|
      end

      if Conf.gvalue("plugin:mpd:testpipe") == "true"
        logger("INFO: mpd-plugin is testing stream pipe (#{Conf.gvalue("main:fifo")})")
        testing = File.open(Conf.gvalue("main:fifo"), File::RDONLY | File::NONBLOCK)
        if testing.gets == nil
          logger("ERROR: mpd-plugin could not connect to pipe. Maybe wrong pipe or mpd is not running")
          @@bot[:cli].set_comment("Waiting for mpd fifo pipe...")
          puts "MPD-Plugin is waiting for mpd fifo pipe..."
        end
        testing.close
      end
      logger "INFO: mpd-plugin is connecting to FIFO"
      @@bot[:cli].player.stream_named_pipe(Conf.gvalue("main:fifo"))
      logger("INFO: mpd-plugin is now connecting to mpd daemon")
      @@bot[:mpd].connect true #without true bot does not @@bot[:cli].text_channel messages other than for !status
      logger("INFO: mpd-plugin is connected.")
      Thread.new do
        Thread.current["user"]=Conf.gvalue("mumble:name")
        Thread.current["process"]="mpd (display info)"
        mpd =@@bot[:mpd]
        lastcurrent = nil
        init = true
        while (true == true)
          sleep 1
          current = mpd.current_song if mpd.connected?
          if current #Would crash if playlist was empty.
            lastcurrent = current if lastcurrent.nil?
            if ( lastcurrent.title != current.title ) || ( init == true ) || lastcurrent.file != current.file
              init = false
              if Conf.gvalue("main:display:comment:set") == true && Conf.gvalue("main:display:comment:aviable") == true
                begin
                  output = ""
                  #if ( @@bot["plugin"]["youtube"][["download"] != nil ) && ( @@bot["plugin"]["mpd"]["musicfolder"] != nil )
                    if File.exist?(Conf.gvalue("plugin:mpd:musicfolder")+current.file.to_s.chomp(File.extname(current.file.to_s))+".jpg")
                      output = @@bot[:cli].get_imgmsg(Conf.gvalue("plugin:mpd:musicfolder")+current.file.to_s.chomp(File.extname(current.file.to_s))+".jpg")
                    end
                  #end
                  output << "<br><table>"
                  output << "<tr><td>Artist:</td><td>#{current.artist}</td></tr>" if current.artist
                  output << "<tr><td>Title:</td><td>#{current.title}</td></tr>" if current.title
                  output << "<tr><td>Album:</td><td>#{current.album}</td></tr>" if current.album
                  output << "<tr><td>Source:</td><td>#{current.file}</td></tr>" if ( current.file ) && ( current.album.nil? ) && ( current.artist.nil? )
                  output << "</table><br>" + @infotemplate
                  @@bot[:cli].set_comment(output)
                rescue NoMethodError
                  logger "#{$!}"
                end
              else
                if current.artist.nil? && current.title.nil? && current.album.nil?
                  channelmessage( "#{current.file}") if ( Conf.gvalue("main:channel_notify").to_i && 0x80 ) == true
                else
                  channelmessage( "#{current.artist} - #{current.title} (#{current.album})") if (Conf.gvalue("main:channel_notify").to_i && 0x80) != 0
                end
              end
            lastcurrent = current
            logger "OK: [displayinfo] updated."
            end
          end
        end
      end

      @@bot[:cli].on_user_state do |msg|
      end

      @@bot[:mpd].volume = Conf.gvalue("plugin:mpd:volume") if Conf.gvalue("plugin:mpd:volume")
    end
    return @@bot
  end

  def name
    if @@bot[:messages].nil?
      "false"
    else
      self.class.name
    end
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{Conf.gvalue("main:control:string")}seek <i>value</i> | <i>+/-value</i></b> - #{I18n.t("plugin_mpd.help.seeka")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}seek <i>mm:ss</i> | <i>+/-mm:ss</i></b> - #{I18n.t("plugin_mpd.help.seekb")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}seek <i>hh:mm:ss</i> | <i>+/-hh:mm:ss</i></b> - #{I18n.t("plugin_mpd.help.seekc")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}crossfade <i>value</i></b> - #{I18n.t("plugin_mpd.help.crossfade")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}next</b> - #{I18n.t("plugin_mpd.help.next")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}prev</b> - #{I18n.t("plugin_mpd.help.prev")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}clear</b> - #{I18n.t("plugin_mpd.help.clear")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}random</b> - #{I18n.t("plugin_mpd.help.random")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}single</b> - #{I18n.t("plugin_mpd.help.single")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}repeat</b> - #{I18n.t("plugin_mpd.help.repeat")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}consume</b> - #{I18n.t("plugin_mpd.help.consume")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}pp</b> - #{I18n.t("plugin_mpd.help.pp")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}stop</b> - #{I18n.t("plugin_mpd.help.stop")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}play</b> - #{I18n.t("plugin_mpd.help.play")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}play first</b> - #{I18n.t("plugin_mpd.help.play_first")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}play last</b> - #{I18n.t("plugin_mpd.help.play_last")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}play <i>number</i></b> - #{I18n.t("plugin_mpd.help.play_number")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}songlist</b> - #{I18n.t("plugin_mpd.help.songlist")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}playlist <i>id</i></b> - #{I18n.t("plugin_mpd.help.playlist")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}save2playlist <i>name</i></b> - #{I18n.t("plugin_mpd.help.save2playlist")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}replaceplaylist <i>name</i></b> - #{I18n.t("plugin_mpd.help.replaceplaylist")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}delplaylist <i>id</i></b> - #{I18n.t("plugin_mpd.help.delplaylist", :controlstring => Conf.gvalue("main:control:string"))}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}song</b> - #{I18n.t("plugin_mpd.help.song")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}status</b> - #{I18n.t("plugin_mpd.help.status")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}playlists</b> - #{I18n.t("plugin_mpd.help.playlists")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}add <i>searchstring</i></b> - #{I18n.t("plugin_mpd.help.searchstring")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}delete <i>ID</i></b> - #{I18n.t("plugin_mpd.help.delete", :controlstring => Conf.gvalue("main:control:string"))}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}where <i>searchstring</i></b> - #{I18n.t("plugin_mpd.help.where")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}queue</b> - #{I18n.t("plugin_mpd.help.queue")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}stats</b> - #{I18n.t("plugin_mpd.help.stats")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}shuffle</b> – #{I18n.t("plugin_mpd.help.shuffle")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}file</b> - #{I18n.t("plugin_mpd.help.file", :controlstring => Conf.gvalue("main:control:string"))}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}v++++</b> - #{I18n.t("plugin_mpd.help.vplus")}"
    h << "<b>#{Conf.gvalue("main:control:string")}v-</b> - #{I18n.t("plugin_mpd.help.vminus")}"
    h << "<b>#{Conf.gvalue("main:control:string")}v <i>value</i></b> - #{I18n.t("plugin_mpd.help.vvalue")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}v</b> - #{I18n.t("plugin_mpd.help.vprint")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}update</b> - #{I18n.t("plugin_mpd.help.update")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}mpdconfig</b> - #{I18n.t("plugin_mpd.help.mpdconfig")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}mpdcommands</b> - #{I18n.t("plugin_mpd.help.mpdcommands")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}mpdnotcommands</b> - #{I18n.t("plugin_mpd.help.mpdnotcommands")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}mpddecoders</b> - #{I18n.t("plugin_mpd.help.mpddecoders")}<br>"
  end

  def handle_chat(msg,message)
    super

    #parsed_message = FIXME

    if message == 'helpmpd'
        privatemessage( help(""))
    end

    if message == 'seek'
      # seek command without a value...
      begin
        privatemessage(I18n.t("plugin_mpd.seek.ok", :time1 => timedecode(@@bot[:mpd].status[:time][0]), :time2 => timedecode(@@bot[:mpd].status[:time][1])))
      rescue
        privatemessage(I18n.t("plugin_mpd.seek.failed"))
      end
    end

    if message[0..3] == 'seek'
      seekto = case message.count ":"
        when 0 then         # Seconds
          if message.match(/^seek [+-]?[0-9]{1,3}$/)
            result = message.match(/^seek ([+-]?[0-9]{1,3})$/)[1]
          else
            return 0
          end
        when 1 then         # Minutes:Seconds
          if message.match(/^seek ([+-]?[0-5]?[0-9]:[0-5]?[0-9])/)
            time = message.match(/^seek ([+-]?[0-5]?[0-9]:[0-5]?[0-9])/)[1].split(/:/)
            case time[0][0]
            when "+"
              result = time[0].to_i * 60 + time[1].to_i
              result = "+" + result.to_s
            when "-"
              result = time[0].to_i * 60 + time[1].to_i * -1
            else
              result = time[0].to_i * 60 + time[1].to_i
            end
          end
        when 2 then         # Hours:Minutes:Seconds
          if message.match(/^seek ([+-]?(?:[01]?[0-9]|2[0-3]):[0-5]?[0-9]:[0-5]?[0-9])/)
            time = message.match(/^seek ([+-]?(?:[01]?[0-9]|2[0-3]):[0-5]?[0-9]:[0-5]?[0-9])/)[1].split(/:/)
            case time[0][0]
            when "+"
              result = time[0].to_i * 3600 + time[1].to_i * 60 + time[2].to_i
              result = "+" + result.to_s
            when "-"
              result = time[0].to_i * 3600 + time[1].to_i * -60 + time[2].to_i * -1
            else
              result = time[0].to_i * 3600 + time[1].to_i * 60 + time[2].to_i
            end
          end
      end
      begin
        @@bot[:mpd].seek seekto
        privatemessage(I18n.t("plugin_mpd.seek.ok", :time1 => timedecode(@@bot[:mpd].status[:time][0]), :time2 => timedecode(@@bot[:mpd].status[:time][1])))
      rescue
        # mpd is old and knows no seek commands
        logger "ERROR: seek without success, maybe mpd version < 0.17 installed"
        privatemessage(I18n.t("plugin_mpd.seek.failed"))
      end
    end

    if message.match(/^crossfade [0-9]{1,3}$/)
      secs = message.match(/^crossfade ([0-9]{1,3})$/)[1].to_i
      @@bot[:mpd].crossfade = secs
    end

    @@bot[:mpd].next if message == 'next'
    @@bot[:mpd].previous if message == 'prev'

    if message == 'clear'
      @@bot[:mpd].clear
      privatemessage(I18n.t("plugin_mpd.clear"))
    end

    if message[0,6] == 'delete'
      list = message.split(/ /)[1..-1].uniq.sort!{|x,y| y.to_i <=> x.to_i}.each do |del|
        begin
          @@bot[:mpd].delete del
          privatemessage( I18n.t("plugin_mpd.delete.ok", :pos => del))
        rescue
          privatemessage( I18n.t("plugin_mpd.delete.failed", :pos => del))
        end
      end
    end

    if message == 'random'
      @@bot[:mpd].random = !@@bot[:mpd].random?
    end

    if message == 'repeat'
      @@bot[:mpd].repeat = !@@bot[:mpd].repeat?
    end

    if message == 'single'
      @@bot[:mpd].single = !@@bot[:mpd].single?
    end

    if message == 'consume'
      @@bot[:mpd].consume = !@@bot[:mpd].consume?
    end

    if message == 'pp'
      @@bot[:mpd].pause = !@@bot[:mpd].paused?
    end

    @@bot[:mpd].stop if message == 'stop'

    if message == 'play'
      if @@bot[:mpd].queue.length == 0
        privatemessage(I18n.t("plugin_mpd.play.empty"))
      else
        @@bot[:mpd].play
        @@bot[:cli].me.deafen false if @@bot[:cli].me.deafened?
        @@bot[:cli].me.mute false if @@bot[:cli].me.muted?
      end
    end

    if message == 'play first'
      begin
        @@bot[:mpd].play 0
        privatemessage(I18n.t("plugin_mpd.play.first"))
      rescue
        privatemessage(I18n.t("plugin_mpd.play.empty"))
      end
    end

    if message == 'play last'
      if @@bot[:mpd].queue.length > 0
        lastsongid = @@bot[:mpd].queue.length.to_i - 1
        @@bot[:mpd].play (lastsongid)
        privatemessage(I18n.t("plugin_mpd.play.last", :id => lastsongid))
      else
        privatemessage(I18n.t("plugin_mpd.play.empty"))
      end
    end

    if message.match(/^play [0-9]{1,3}$/)
      tracknumber = message.match(/^play ([0-9]{1,3})$/)[1].to_i
      begin
        @@bot[:mpd].play tracknumber
      rescue
        privatemessage(I18n.t("plugin_mpd.play.notexist", :id => tracknumber.to_s))
      end
      @@bot[:cli].me.deafen false if @@bot[:cli].me.deafened?
      @@bot[:cli].me.mute false if @@bot[:cli].me.muted?
    end

    if message == 'songlist'
      block = 0
      out = ""
      @@bot[:mpd].songs.each do |song|
        if block >= 50
          privatemessage(out.to_s)
          out = ""
          block = 0
        end
        out << "<br/>" + song.file.to_s
        block += 1
      end
      privatemessage(out.to_s)
    end

    if message == 'stats'
      out = "<table>"
      @@bot[:mpd].stats.each do |key, value|
        case
        when key.to_s == 'uptime'
          out << "<tr><td>#{key}</td><td>#{timedecode(value)}</td></tr>"
        when key.to_s == 'playtime'
          out << "<tr><td>#{key}</td><td>#{timedecode(value)}</td></tr>"
        when key.to_s == 'db_playtime'
          out << "<tr><td>#{key}</td><td>#{timedecode(value)}</td></tr>"
        else
          out << "<tr><td>#{key}</td><td>#{value}</td></tr>"
        end
      end
      out << "</table>"
      privatemessage( out)
    end

    if message == 'queue'
      if @@bot[:mpd].queue.length > 0
        text_out ="<table><th><td>#</td><td>Name</td></th>"
        songnr = 0
        playing = -1
        playing = @@bot[:mpd].current_song.pos if !@@bot[:mpd].current_song.nil?
        @@bot[:mpd].queue.each do |song|
          text_out << "<tr><td>#{songnr}</td><td>"
          songnr == playing ? text_out << "<b>" : nil
          song.title.to_s == "" ? (text_out<<"#{song.file}") : (text_out<<"#{song.title}")
          songnr == playing ? text_out << "</b>" : nil
          songnr += 1
        end
        text_out << "</table>"
      else
        text_out = I18n.t("plugin_mpd.queue.empty")
      end
      privatemessage( text_out)
    end

    if message[0,15] == 'replaceplaylist'
      name = message.gsub("replaceplaylist", "").lstrip
      if name != ""
        @@bot[:mpd].playlists.each do |pl|
          if pl.name == name
            pl.destroy
          end
        end
        playlist = MPD::Playlist.new(@@bot[:mpd], name)
        @@bot[:mpd].queue.each do |song|
            playlist.add song
        end
        privatemessage ( I18n.t("plugin_mpd.replaceplaylist.ok", :name => name) )
      else
        privatemessage ( I18n.t("plugin_mpd.replaceplaylist.failed") )
      end
    end

    if message[0,13] == 'save2playlist'
      name = message.gsub("save2playlist", "").lstrip
      if name != ""
        out = I18n.t("plugin_mpd.save2playlist.new", :name => name)
        @@bot[:mpd].playlists.each do |pl|
          out = I18n.t("plugin_mpd.save2playlist.add", :name => name) if pl.name == name
        end
        playlist = MPD::Playlist.new(@@bot[:mpd], name)
        @@bot[:mpd].queue.each do |song|
            playlist.add song
        end
        privatemessage( out + I18n.t("plugin_mpd.save2playlist.info", :controlstring => Conf.gvalue("main:control:string")) )
      else
        privatemessage( I18n.t("plugin_mpd.save2playlist.failed") )
      end
    end

    if message.match(/^delplaylist [0-9]{1,3}.*$/)
      playlist_id = message.match(/^delplaylist ([0-9]{1,3})$/)[1].to_i
      begin
        playlist = @@bot[:mpd].playlists[playlist_id]
        privatemessage( I18n.t("plugin_mpd.delplaylist.ok", :name => playlist.name) )
        playlist.destroy
      rescue
        privatemessage( I18n.t("plugin_mpd.delplaylist.failed" ))
      end
    end

    if ( message[0,5] == 'where' )
      search = message.gsub("where", "").lstrip.tr('"\\','')
      text_out = I18n.t("plugin_mpd.where.nothing")
      if search != ""
        text_out ="#{I18n.t("plugin_mpd.where.found")}<br/>"
        @@bot[:mpd].where(any: "#{search}").each do |song|
          text_out << "#{song.file}<br/>"
        end
      end
      privatemessage( text_out)
    end

    if ( message[0,3] == 'add' )
      search = (message.gsub("add", "").lstrip).tr('"\\','')
      text_out = I18n.t("plugin_mpd.add.empty")
      if search != ""
        text_out ="#{I18n.t("plugin_mpd.add.added")}<br/>"
        count = 0
        @@bot[:mpd].where(any: "#{search}").each do |song|
          text_out << "add #{song.file}<br/>"
          @@bot[:mpd].add(song)
          count += 1
        end
        text_out = I18n.t("plugin_mpd.add.nothing") if count == 0
      end
      privatemessage( text_out)
    end

    if message == 'playlists'
      text_out = ""
      counter = 0
      @@bot[:mpd].playlists.each do |pl|
        text_out = text_out + "#{counter} - #{pl.name}<br/>"
        counter += 1
      end
      privatemessage( I18n.t("plugin_mpd.playlists", :list => text_out) )
    end

    if message.match(/^playlist [0-9]{1,3}.*$/)
      playlist_id = message.match(/^playlist ([0-9]{1,3})$/)[1].to_i
      begin
        playlist = @@bot[:mpd].playlists[playlist_id]
        @@bot[:mpd].clear
        playlist.load
        @@bot[:mpd].play
        @@bot[:cli].me.deafen false if @@bot[:cli].me.deafened?
        @@bot[:cli].me.mute false if @@bot[:cli].me.muted?

        privatemessage( I18n.t("plugin_mpd.playlist.loaded", :name => playlist.name) )
      rescue
        privatemessage( I18n.t("plugin_mpd.playlist.notfound") )
      end
    end

    if message == 'status'
      out = "<table>"
      @@bot[:mpd].status.each do |key, value|

        case
        when key.to_s == 'volume'
          out << "<tr><td>#{I18n.t("plugin_mpd.status.volume")}</td><td>#{value}%</td></tr>"
        when key.to_s == 'repeat'
          if value
            repeat = I18n.t("plugin_mpd.status._on")
          else
            repeat = I18n.t("plugin_mpd.status._off")
          end
          out << "<tr><td>#{I18n.t("plugin_mpd.status.repeat")}</td><td>#{repeat}</td></tr>"
        when key.to_s == 'random'
          if value
            random = I18n.t("plugin_mpd.status._on")
          else
            random = I18n.t("plugin_mpd.status._off")
          end
          out << "<tr><td>#{I18n.t("plugin_mpd.status.random")}</td><td>#{random}</td></tr>"
        when key.to_s == 'single'
          if value
            single = I18n.t("plugin_mpd.status._on")
          else
            single = I18n.t("plugin_mpd.status._off")
          end
          out << "<tr><td>#{I18n.t("plugin_mpd.status.single")}</td><td>#{single}</td></tr>"
        when key.to_s == 'consume'
          if value
            consume = I18n.t("plugin_mpd.status._on")
          else
            consume = I18n.t("plugin_mpd.status._off")
          end
          out << "<tr><td>#{I18n.t("plugin_mpd.status.consume")}</td><td>#{consume}</td></tr>"
        when key.to_s == 'playlist'
          out << "<tr><td>#{I18n.t("plugin_mpd.status.playlist")}</td><td>#{value}</td></tr>"

          #FIXME Not possible, because the "value" in this context is random(?) after every playlist loading.
          #playlist = @@bot[:mpd].playlists[value.to_i]
          #if not playlist.nil?
          #  out << "<tr><td>Current playlist:</td><td>#{playlist.name}</td></tr>"
          #else
          #  out << "<tr><td>Current playlist:</td><td>#{value}</td></tr>"
          #end
        when key.to_s == 'playlistlength'
          out << "<tr><td>#{I18n.t("plugin_mpd.status.playlistlength")}</td><td valign='bottom'>#{timedecode(value)}</td></tr>"
        when key.to_s == 'mixrampdb'
          out << "<tr><td>#{I18n.t("plugin_mpd.status.mixrampdb")}</td><td>#{value}</td></tr>"
        when key.to_s == 'state'
          case
          when value.to_s == 'play'
            state = I18n.t("plugin_mpd.status.play")
          when value.to_s == 'stop'
            state = I18n.t("plugin_mpd.status.stop")
          when value.to_s == 'pause'
            state = I18n.t("plugin_mpd.status.pause")
          else
            state = I18n.t("plugin_mpd.status.unknown")
          end
          out << "<tr><td>Current state:</td><td>#{state}</td></tr>"
        when key.to_s == 'song'
          current = @@bot[:mpd].current_song
          if current
            out << "<tr><td>#{I18n.t("plugin_mpd.status.song")}</td><td>#{current.artist} - #{current.title} (#{current.album})</td></tr>"
          else
            out << "<tr><td>#{I18n.t("plugin_mpd.status.mixrampdb")}</td><td>#{value})</td></tr>"
          end
        when key.to_s == 'songid'
          #queue = Queue.new
          ##queue = @@bot[:mpd].queue
          #puts "queue: " + queue.inspect
          #current_song = queue.song_with_id(value.to_i)

          #out << "<tr><td>Current songid:</td><td>#{current_song}</td></tr>"
          out << "<tr><td>#{I18n.t("plugin_mpd.status.songid")}</td><td>#{value}</td></tr>"
        when key.to_s == 'time'
            out << "<tr><td>#{I18n.t("plugin_mpd.status.time")}</td><td>#{timedecode(value[0])}/#{timedecode(value[1])}</td></tr>"
        when key.to_s == 'elapsed'
          out << "<tr><td>#{I18n.t("plugin_mpd.status.elapsed")}</td><td>#{timedecode(value)}</td></tr>"
        when key.to_s == 'bitrate'
          out << "<tr><td>#{I18n.t("plugin_mpd.status.bitrate")}</td><td>#{value}</td></tr>"
        when key.to_s == 'audio'
          out << "<tr><td>#{I18n.t("plugin_mpd.status.audio")}</td><td>samplerate(#{value[0]}), bitrate(#{value[1]}), channels(#{value[2]})</td></tr>"
        when key.to_s == 'nextsong'
          out << "<tr><td>#{I18n.t("plugin_mpd.status.nextsong")}</td><td valign='bottom'>#{value}</td></tr>"
        when key.to_s == 'nextsongid'
          out << "<tr><td>#{I18n.t("plugin_mpd.status.nextsongid")}</td><td valign='bottom'>#{value}</td></tr>"
        else
          out << "<tr><td>#{key}:</td><td>#{value}</td></tr>"
        end

      end
      out << "</table>"
      privatemessage(out)
    end

    if message == 'file'
      current = @@bot[:mpd].current_song
      privatemessage( I18n.t("plugin_mpd.file", :file => current.file)) if current
    end

    if message == 'song'
      current = @@bot[:mpd].current_song
      if current #Would crash if playlist was empty.
        privatemessage( "#{current.artist} - #{current.title} (#{current.album})")
      else
        privatemessage( I18n.t("plugin_mpd.song.no") )
      end
    end

    if message == 'shuffle'
      @@bot[:mpd].shuffle
      privatemessage( I18n.t("plugin_mpd.shuffle") )
    end

    if message == 'v'
      volume = @@bot[:mpd].volume
      privatemessage( I18n.t("plugin_mpd.volume.current", :volume => volume))
    end

    if message.match(/^v [0-9]{1,3}$/)
      volume = message.match(/^v ([0-9]{1,3})$/)[1].to_i

      if (volume >=0 ) && (volume <= 100)
        @@bot[:mpd].volume = volume
      else
        privatemessage( I18n.t("plugin_mpd.volume.range") )
      end
    end

    if message.match(/^v[-]+$/)
      multi = message.match(/^v([-]+)$/)[1].scan(/\-/).length
      volume = ((@@bot[:mpd].volume).to_i - 5 * multi)
      if volume < 0
        channelmessage( I18n.t("plugin_mpd.volume.toolow") )
        volume = 0
      end
      @@bot[:mpd].volume = volume
    end

    if message.match(/^v[+]+$/)
      multi = message.match(/^v([+]+)$/)[1].scan(/\+/).length
      volume = ((@@bot[:mpd].volume).to_i + 5 * multi)
      if volume > 100
        channelmessage( I18n.t("plugin_mpd.volume.toohigh") )
        volume = 100
      end
      @@bot[:mpd].volume = volume
    end

    if message == 'update'
      @@bot[:mpd].update
      privatemessage(I18n.t("plugin_mpd.update.run"))
      while @@bot[:mpd].status[:updating_db] do
        sleep 0.5
      end
      privatemessage(I18n.t("plugin_mpd.update.done"))
    end

    if message == 'displayinfo'
      begin
        if Conf.gvalue("main:display:comment.set") == true
          Conf.svalue("main:display:comment.set", false)
          privatemessage( I18n.t("plugin_mpd.displayinfo.channel") )
          @@bot[:cli].set_comment(@template_if_comment_disabled % [Conf.gvalue("main:control:string")])
        else
          Conf.svalue("main:display:comment.set", true)
          privatemessage( I18n.t("plugin_mpd.displayinfo.comment") )
          @@bot[:cli].set_comment(@template_if_comment_enabled)
        end
      rescue NoMethodError
        logger "#{$!}"
      end
    end

    if message == 'mpdconfig'
      begin
        config = @@bot[:mpd].config
      rescue
        config = I18n.t("plugin_mpd.mpdconfig")
      end
      privatemessage( config)
    end

    if message == 'mpdcommands'
      output = ""
      @@bot[:mpd].commands.each do |command|
        output << "<br>#{command}"
      end
      privatemessage( output)
    end

    if message == 'mpdnotcommands'
      output = ""
      @@bot[:mpd].notcommands.each do |command|
        output << "<br\>#{command}"
      end
      privatemessage( output)
    end

    if message == 'mpdurlhandlers'
      output = ""
      @@bot[:mpd].url_handlers.each do |handler|
        output << "<br\>#{handler}"
      end
      privatemessage( output)
    end

    if message == 'mpddecoders'
      output = "<table>"
      @@bot[:mpd].decoders.each do |decoder|
        output << "<tr>"
        output << "<td>#{decoder[:plugin]}</td>"
        output << "<td>"
        begin
        decoder[:suffix].each do |suffix|
          output << "#{suffix} "
        end
        output << "</td>"
        rescue
          output << "#{decoder[:suffix]}"
        end
      end
      output << "</table>"
      privatemessage( output)
    end
  end

  private

  def timedecode(time)
    begin
      #Code from https://stackoverflow.com/questions/19595840/rails-get-the-time-difference-in-hours-minutes-and-seconds
      now_mm, now_ss = time.to_i.divmod(60)
      now_hh, now_mm = now_mm.divmod(60)
      if ( now_hh < 24 )
        now = "%02d:%02d:%02d" % [now_hh, now_mm, now_ss]
      else
        now_dd, now_hh = now_hh.divmod(24)
        now = "%04d days %02d:%02d:%02d" % [now_dd, now_hh, now_mm, now_ss]
      end
    rescue
      now "unknown"
    end
  end

end
