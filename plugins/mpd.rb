# a pluginbot plugin

class Mpd < Plugin

  def init(init)
    super
    @@bot = init
    #init default template
    @infotemplate = "send <b>#{@@bot["main"]["control"]["string"]}help</b> or <b>#{@@bot["main"]["<"]["string"]}about</b> for more information about me."
    if ( @@bot[:messages] ) && ( @@bot[:mpd].nil? ) then
      logger("INFO: INIT plugin #{self.class.name}.")
      @@bot[:mpd] = MPD.new @@bot["plugin"]["mpd"]["host"], @@bot["plugin"]["mpd"]["port"].to_i

      @@bot[:mpd].on :volume do |volume|
        @@bot[:messages].sendmessage("Volume was set to: #{volume}%." , 0x01)
      end

      @@bot[:mpd].on :error do |error|
        channelmessage( "<span style='color:red;font-weight:bold;>An error occured: #{error}.</span>")
      end

      @@bot[:mpd].on :updating_db do |jobid|
        channelmessage( "I am running a database update just now ... new songs :)<br>My job id is: #{jobid}.") if (@@bot["main"]["channel_notify"].to_i & 0x02) != 0
      end

      @@bot[:mpd].on :random do |random|
        if random
          random = "On"
        else
          random = "Off"
        end
        channelmessage( "Random mode is now: #{random}.") if (@@bot["main"]["channel_notify"].to_i & 0x04) != 0
      end

      @@bot[:mpd].on :state  do |state|
        if @@bot["main"]["channel_notify"].to_i & 0x80 != 0 then
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
        channelmessage( "Single mode is now: #{single}.") if (@@bot["main"]["channel_notify"].to_i & 0x08) != 0
      end

      @@bot[:mpd].on :consume do |consume|
        if consume
          consume = "On"
        else
          consume = "Off"
        end

        channelmessage( "Consume mode is now: #{consume}.") if (@@bot["main"]["channel_notify"].to_i & 0x10) != 0
      end

      @@bot[:mpd].on :xfade do |xfade|
        if xfade.to_i == 0
          xfade = "Off"
          channelmessage( "Crossfade is now: #{xfade}.") if (@@bot["main"]["channel_notify"] & 0x20) != 0
        else
          channelmessage( "Crossfade time (in seconds) is now: #{xfade}.") if (@@bot["main"]["channel_notify"].to_i & 0x20) != 0
        end
      end

      @@bot[:mpd].on :repeat do |repeat|
        if repeat
          repeat = "On"
        else
          repeat = "Off"
        end
        channelmessage( "Repeat mode is now: #{repeat}.") if (@@bot["main"]["channel_notify"].to_i & 0x40) != 0
      end

      @@bot[:mpd].on :song do |current|
      end

      if @@bot["plugin"]["mpd"]["testpipe"] == "true"
        logger("INFO: mpd-plugin is testing stream pipe (#{@@bot["main"]["fifo"]})")
        testing = File.open(@@bot["main"]["fifo"], File::RDONLY | File::NONBLOCK)
        if testing.gets == nil
          logger("ERROR: mpd-plugin could not connect to pipe. Maybe wrong pipe or mpd is not running")
          @@bot[:cli].set_comment("Waiting for mpd fifo pipe...")
          puts "MPD-Plugin is waiting for mpd fifo pipe..."
        end
        testing.close
      end
      logger "INFO: mpd-plugin is connecting to FIFO"
      @@bot[:cli].player.stream_named_pipe(@@bot["main"]["fifo"])
      logger("INFO: mpd-plugin is now connecting to mpd daemon")
      @@bot[:mpd].connect true #without true bot does not @@bot[:cli].text_channel messages other than for !status
      logger("INFO: mpd-plugin is connected.")
      Thread.new do
        Thread.current["user"]=@@bot["mumble"]["name"]
        Thread.current["process"]="mpd (display info)"
        mpd =@@bot[:mpd]
        lastcurrent = nil
        init = true
        while (true == true)
          sleep 1
          current = mpd.current_song if mpd.connected?
          if current #Would crash if playlist was empty.
            lastcurrent = current if lastcurrent.nil?
            if ( lastcurrent.title != current.title ) || ( init == true )
              init = false
              if @@bot["main"]["display"]["comment"] == true && @@bot[:set_comment_available] == true
                begin
                  output = ""
                  #if ( @@bot["plugin"]["youtube"][["download"] != nil ) && ( @@bot["plugin"]["mpd"]["musicfolder"] != nil )
                    if File.exist?(@@bot["plugin"]["mpd"]["musicfolder"]+current.file.to_s.chomp(File.extname(current.file.to_s))+".jpg")
                      output = @@bot[:cli].get_imgmsg(@@bot["plugin"]["mpd"]["musicfolder"]+current.file.to_s.chomp(File.extname(current.file.to_s))+".jpg")
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
                  channelmessage( "#{current.file}") if ( @@bot["main"]["channel_notify"].to_i && 0x80 ) == true
                else
                  channelmessage( "#{current.artist} - #{current.title} (#{current.album})") if (@@bot["main"]["channel_notify"].to_i && 0x80) != 0
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

      @@bot[:mpd].volume = @@bot["plugin"]["mpd"]["volume"] if @@bot["plugin"]["mpd"]["volume"]
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
    h << "<b>#{@@bot["main"]["control"]["string"]}seek <i>value</i> | <i>+/-value</i></b> - Seek to an absolute position (in seconds). Use +value or -value to seek relative to the current position.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}seek <i>mm:ss</i> | <i>+/-mm:ss</i></b> - Seek to an absolute position. Use + or - to seek relative to the current position.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}seek <i>hh:mm:ss</i> | <i>+/-hh:mm:ss</i></b> - Seek to an absolute position. Use + or - to seek relative to the current position.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}crossfade <i>value</i></b> - Set Crossfade to value seconds, 0 to disable crossfading.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}next</b> - Play next title in the queue.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}prev</b> - Play previous title in the queue.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}clear</b> - Clear the playqueue.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}random</b> - Toggle random mode.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}single</b> - Toggle single mode.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}repeat</b> - Toggle repeat mode.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}consume</b> - Toggle consume mode. If this mode is enabled, songs will be removed from the play queue once they were played.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}pp</b> - Toggle pause/play.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}stop</b> - Stop playing.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}play</b> - Start playing.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}play first</b> - Play the first song in the queue.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}play last</b> - Play the last song in the queue.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}play <i>number</i></b> - Play title on position <i>number</i> in queue.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}songlist</b> - Print the list of ALL songs in the MPD collection.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}playlist <i>id</i></b> - Load the playlist referenced by the id.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}save2playlist <i>name</i></b> - Append queue into a playlist named 'name'<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}replaceplaylist <i>name</i></b> - Overwrite playlist 'name' with queue<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}delplaylist <i>id</i></b> - Remove a playlist with the given id. Use #{@@bot["main"]["control"]["string"]}playlists to get a list of available playlists.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}song</b> - Print some information about the currently played song.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}status</b> - Print current status of MPD.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}playlists</b> - Print the available playlists from MPD.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}add <i>searchstring</i></b> - Find song(s) by searchstring and print matches.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}delete <i>ID</i></b> - Delete an entry from the current queue. Use #{@@bot["main"]["control"]["string"]}queue to get the IDs of all songs in the current queue.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}where <i>searchstring</i></b> - Find song(s) by searchstring and print matches.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}queue</b> - Print the current play queue.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}stats</b> - Print some interesing MPD statistics.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}shuffle</b> – Play songs from the play queue in a random order.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}file</b> - Print the filename of the current song. This is useful if the file doesn't have ID3 tags and so the <b>#{@@bot["main"]["control"]["string"]}song</b> command shows nothing.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}v++++</b> - Turns volume 20% up.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}v-</b> - Turns volume 5% down.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}v <i>value</i></b> - Set the volume to the given value.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}v</b> - Print the current playback volume.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}update</b> - Start a MPD database update.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}mpdconfig</b> - Try to read mpd config.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}mpdcommands</b> - Show what commands mpd do allow to Bot (not to you!).<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}mpdnotcommands</b> - Show what commands mpd disallowed to Bot.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}mpddecoders</b> - Show enabled decoders and what they can decode for your mpd.<br>"
  end

  def handle_chat(msg,message)
    super
    if message == 'helpmpd'
        privatemessage( help(""))
    end

    if message == 'seek'
      # seek command without a value...
      begin
        privatemessage("Now on position #{timedecode @@bot[:mpd].status[:time][0]}/#{timedecode @@bot[:mpd].status[:time][1]}.")
      rescue
        privatemessage("Seeking failed")
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
        channelmessage( "Now on position #{timedecode @@bot[:mpd].status[:time][0]}/#{timedecode @@bot[:mpd].status[:time][1]}.")
      rescue
        # mpd is old and knows no seek commands
        logger "ERROR: seek without success, maybe mpd version < 0.17 installed"
        channelmessage( "Seeking failed.")
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
      privatemessage( "The playqueue was cleared.")
    end

    if message[0,6] == 'delete'
      list = message.split(/ /)[1..-1].uniq.sort!{|x,y| y.to_i <=> x.to_i}.each do |del|
        begin
          @@bot[:mpd].delete del
          privatemessage( "Deleted Position <b>'#{del}'</b>.")
        rescue
          privatemessage( "Sorry, could not delete <b>'#{del}'</b>.")
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
        privatemessage("My queue is empty, cannot start playing.")
      else
        @@bot[:mpd].play
        @@bot[:cli].me.deafen false if @@bot[:cli].me.deafened?
        @@bot[:cli].me.mute false if @@bot[:cli].me.muted?
      end
    end

    if message == 'play first'
      begin
        @@bot[:mpd].play 0
        privatemessage("Playing first song in the queue (0).")
      rescue
        privatemessage("There is no title in the queue, cant play the first entry.")
      end
    end

    if message == 'play last'
      if @@bot[:mpd].queue.length > 0
        lastsongid = @@bot[:mpd].queue.length.to_i - 1
        @@bot[:mpd].play (lastsongid)
        privatemessage("Playing last song in the queue (#{lastsongid}).")
      else
        privatemessage("There is no title in the queue, cant play the first entry.")
      end
    end

    if message.match(/^play [0-9]{1,3}$/)
      tracknumber = message.match(/^play ([0-9]{1,3})$/)[1].to_i
      begin
        @@bot[:mpd].play tracknumber
      rescue
        privatemessage("Title on position #{tracknumber.to_s} does not exist")
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
        text_out = "The queue is empty."
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
        privatemessage ( "Songs saved in playlist \"#{name}\"." )
      else
        privatemessage ( "no playlist name gaven." )
      end
    end

    if message[0,13] == 'save2playlist'
      name = message.gsub("save2playlist", "").lstrip
      if name != ""
        out = "Songs saved in new playlist with \"#{name}\"."
        @@bot[:mpd].playlists.each do |pl|
          out = "Songs added to playlist \"#{name}\"." if pl.name == name
        end
        playlist = MPD::Playlist.new(@@bot[:mpd], name)
        @@bot[:mpd].queue.each do |song|
            playlist.add song
        end
        privatemessage( out + " Use the command #{@@bot["main"]["control"]["string"]}playlists to get a list of all available playlists." )
      else
        privatemessage( "no playlist name gaven.")
      end
    end

    if message.match(/^delplaylist [0-9]{1,3}.*$/)
      playlist_id = message.match(/^delplaylist ([0-9]{1,3})$/)[1].to_i
      begin
        playlist = @@bot[:mpd].playlists[playlist_id]
        playlist.destroy
        privatemessage( "The playlist \"#{playlist.name}\" deleted.")
      rescue
        privatemessage( "Sorry, the given playlist id does not exist.")
      end
    end

    if ( message[0,5] == 'where' )
      search = message.gsub("where", "").lstrip.tr('"\\','')
      text_out = "you should search not nothing!"
      if search != ""
        text_out ="found:<br/>"
        @@bot[:mpd].where(any: "#{search}").each do |song|
          text_out << "#{song.file}<br/>"
        end
      end
      privatemessage( text_out)
    end

    if ( message[0,3] == 'add' )
      search = (message.gsub("add", "").lstrip).tr('"\\','')
      text_out = "search is empty"
      if search != ""
        text_out ="added:<br/>"
        count = 0
        @@bot[:mpd].where(any: "#{search}").each do |song|
          text_out << "add #{song.file}<br/>"
          @@bot[:mpd].add(song)
          count += 1
        end
        text_out = "found nothing" if count == 0
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
      privatemessage( "I know the following playlists:<br>#{text_out}")
    end

    if message.match(/^playlist [0-9]{1,3}.*$/)
      playlist_id = message.match(/^playlist ([0-9]{1,3})$/)[1].to_i
      begin
        playlist = @@bot[:mpd].playlists[playlist_id]
        @@bot[:mpd].clear
        playlist.load
        @@bot[:mpd].play
        privatemessage( "The playlist \"#{playlist.name}\" was loaded and starts now.")
      rescue
        privatemessage( "Sorry, the given playlist id does not exist.")
      end
    end

    if message == 'status'
      out = "<table>"
      @@bot[:mpd].status.each do |key, value|

        case
        when key.to_s == 'volume'
          out << "<tr><td>Current volume:</td><td>#{value}%</td></tr>"
        when key.to_s == 'repeat'
          if value
            repeat = "on"
          else
            repeat = "off"
          end
          out << "<tr><td>Repeat mode:</td><td>#{repeat}</td></tr>"
        when key.to_s == 'random'
          if value
            random = "on"
          else
            random = "off"
          end
          out << "<tr><td>Random mode:</td><td>#{random}</td></tr>"
        when key.to_s == 'single'
          if value
            single = "on"
          else
            single = "off"
          end
          out << "<tr><td>Single mode:</td><td>#{single}</td></tr>"
        when key.to_s == 'consume'
          if value
            consume = "on"
          else
            consume = "off"
          end
          out << "<tr><td>Consume mode:</td><td>#{consume}</td></tr>"
        when key.to_s == 'playlist'
          out << "<tr><td>Current playlist:</td><td>#{value}</td></tr>"

          #FIXME Not possible, because the "value" in this context is random(?) after every playlist loading.
          #playlist = @@bot[:mpd].playlists[value.to_i]
          #if not playlist.nil?
          #  out << "<tr><td>Current playlist:</td><td>#{playlist.name}</td></tr>"
          #else
          #  out << "<tr><td>Current playlist:</td><td>#{value}</td></tr>"
          #end
        when key.to_s == 'playlistlength'
          out << "<tr><td>Song count in current queue/playlist:</td><td valign='bottom'>#{timedecode(value)}</td></tr>"
        when key.to_s == 'mixrampdb'
          out << "<tr><td>Mixramp db:</td><td>#{value}</td></tr>"
        when key.to_s == 'state'
          case
          when value.to_s == 'play'
            state = "playing"
          when value.to_s == 'stop'
            state = "stopped"
          when value.to_s == 'pause'
            state = "paused"
          else
            state = "unknown state"
          end
          out << "<tr><td>Current state:</td><td>#{state}</td></tr>"
        when key.to_s == 'song'
          current = @@bot[:mpd].current_song
          if current
            out << "<tr><td>Current song:</td><td>#{current.artist} - #{current.title} (#{current.album})</td></tr>"
          else
            out << "<tr><td>Current song:</td><td>#{value})</td></tr>"
          end
        when key.to_s == 'songid'
          #queue = Queue.new
          ##queue = @@bot[:mpd].queue
          #puts "queue: " + queue.inspect
          #current_song = queue.song_with_id(value.to_i)

          #out << "<tr><td>Current songid:</td><td>#{current_song}</td></tr>"
          out << "<tr><td>Current songid:</td><td>#{value}</td></tr>"
        when key.to_s == 'time'
            out << "<tr><td>Current position:</td><td>#{timedecode(value[0])}/#{timedecode(value[1])}</td></tr>"
        when key.to_s == 'elapsed'
          out << "<tr><td>Elapsed:</td><td>#{timedecode(value)}</td></tr>"
        when key.to_s == 'bitrate'
          out << "<tr><td>Current song bitrate:</td><td>#{value}</td></tr>"
        when key.to_s == 'audio'
          out << "<tr><td>Audio properties:</td><td>samplerate(#{value[0]}), bitrate(#{value[1]}), channels(#{value[2]})</td></tr>"
        when key.to_s == 'nextsong'
          out << "<tr><td>Position ID of next song to play (in the queue):</td><td valign='bottom'>#{value}</td></tr>"
        when key.to_s == 'nextsongid'
          out << "<tr><td>Song ID of next song to play:</td><td valign='bottom'>#{value}</td></tr>"
        else
          out << "<tr><td>#{key}:</td><td>#{value}</td></tr>"
        end

      end
      out << "</table>"
      privatemessage(out)
    end

    if message == 'file'
      current = @@bot[:mpd].current_song
      privatemessage( "Filename of currently played song:<br>#{current.file}</span>") if current
    end

    if message == 'song'
      current = @@bot[:mpd].current_song
      if current #Would crash if playlist was empty.
        privatemessage( "#{current.artist} - #{current.title} (#{current.album})")
      else
        privatemessage( "No song is played currently.")
      end
    end

    if message == 'shuffle'
      @@bot[:mpd].shuffle
      privatemessage( "Shuffle, shuffle and get a new order. :)")
    end

    if message == 'v'
      volume = @@bot[:mpd].volume
      privatemessage( "Current volume is #{volume}%.")
    end

    if message.match(/^v [0-9]{1,3}$/)
      volume = message.match(/^v ([0-9]{1,3})$/)[1].to_i

      if (volume >=0 ) && (volume <= 100)
        @@bot[:mpd].volume = volume
      else
        privatemessage( "Volume can be within a range of 0 to 100")
      end
    end

    if message.match(/^v[-]+$/)
      multi = message.match(/^v([-]+)$/)[1].scan(/\-/).length
      volume = ((@@bot[:mpd].volume).to_i - 5 * multi)
      if volume < 0
        channelmessage( "Volume can't be set to &lt; 0.")
        volume = 0
      end
      @@bot[:mpd].volume = volume
    end

    if message.match(/^v[+]+$/)
      multi = message.match(/^v([+]+)$/)[1].scan(/\+/).length
      volume = ((@@bot[:mpd].volume).to_i + 5 * multi)
      if volume > 100
        channelmessage( "Volume can't be set to &gt; 100.")
        volume = 100
      end
      @@bot[:mpd].volume = volume
    end

    if message == 'update'
      @@bot[:mpd].update
      privatemessage("Running database update...")
      while @@bot[:mpd].status[:updating_db] do
        sleep 0.5
      end
      privatemessage("Done.")
    end

    if message == 'displayinfo'
      begin
        if @@bot["main"]["display"]["comment"] == true
          @@bot["main"]["display"]["comment"] = false
          privatemessage( "Output is now \"Channel\"")
          @@bot[:cli].set_comment(@template_if_comment_disabled % [@@bot["main"]["control"]["string"]])
        else
          @@bot["main"]["display"]["comment"] = true
          privatemessage( "Output is now \"Comment\"")
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
        config = "Configuration only for local clients readable"
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
