# a pluginbot plugin

class Mpd < Plugin
    
    def init(init)
        super
        @@bot = init
        #init default template
        @infotemplate = "send #{@@bot[:controlstring]}help or #{@@bot[:controlstring]}about for more information over me."

        if ( @@bot[:messages] != nil ) && ( @@bot[:mpd] == nil ) then
            @@bot[:mpd] = MPD.new @@bot[:mpd_host], @@bot[:mpd_port].to_i

            @@bot[:mpd].on :volume do |volume|
                @@bot[:messages].sendmessage("Volume was set to: #{volume}%." , 0x01)
            end

            @@bot[:mpd].on :error do |error|
                channelmessage( "<span style='color:red;font-weight:bold;>An error occured: #{error}.</span>") 
            end

            @@bot[:mpd].on :updating_db do |jobid|
                channelmessage( "I am running a database update just now ... new songs :)<br>My job id is: #{jobid}.") if (@@bot[:chan_notify] & 0x02) != 0
            end

            @@bot[:mpd].on :random do |random|
                if random
                    random = "On"
                else
                    random = "Off"
                end
                channelmessage( "Random mode is now: #{random}.") if (@@bot[:chan_notify] & 0x04) != 0
            end

            @@bot[:mpd].on :state  do |state|
                if @@bot[:chan_notify] & 0x80 != 0 then
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
                channelmessage( "Single mode is now: #{single}.") if (@@bot[:chan_notify] & 0x08) != 0
            end

            @@bot[:mpd].on :consume do |consume|
                if consume
                    consume = "On"
                else
                    consume = "Off"
                end

                channelmessage( "Consume mode is now: #{consume}.") if (@@bot[:chan_notify] & 0x10) != 0
            end

            @@bot[:mpd].on :xfade do |xfade|
                if xfade.to_i == 0
                    xfade = "Off"
                    channelmessage( "Crossfade is now: #{xfade}.") if (@@bot[:chan_notify] & 0x20) != 0
                else
                    channelmessage( "Crossfade time (in seconds) is now: #{xfade}.") if (@@bot[:chan_notify] & 0x20) != 0 
                end
            end

            @@bot[:mpd].on :repeat do |repeat|
                if repeat
                    repeat = "On"
                else
                    repeat = "Off"
                end
                channelmessage( "Repeat mode is now: #{repeat}.") if (@@bot[:chan_notify] & 0x40) != 0
            end

            @@bot[:mpd].on :song do |current|
            end

            @@bot[:cli].player.stream_named_pipe(@@bot[:mpd_fifopath]) 
            @@bot[:mpd].connect true #without true bot does not @@bot[:cli].text_channel messages other than for !status
            
            main = Thread.new do
                mpd =@@bot[:mpd]
                lastcurrent = nil
                init = true
                while (true == true)
                    sleep 1
                    current = mpd.current_song if mpd.connected?
                    if not current.nil? #Would crash if playlist was empty.
                        lastcurrent = current if lastcurrent.nil? 
                        if ( lastcurrent.title != current.title ) || ( init == true )
                            init = false
                            if @@bot[:use_comment_for_status_display] == true && @@bot[:set_comment_available] == true
                                begin
                                    if ( @@bot[:youtube_downloadsubdir] != nil ) && ( @@bot[:mpd_musicfolder] != nil )
                                        if File.exist?(@@bot[:mpd_musicfolder]+current.file.to_s.chomp(File.extname(current.file.to_s))+".jpg")
                                            image = @@bot[:cli].get_imgmsg(@@bot[:mpd_musicfolder]+current.file.to_s.chomp(File.extname(current.file.to_s))+".jpg")
                                        else
                                            image = @@bot[:logo]
                                        end
                                    else
                                         image = @@bot[:logo]
                                    end
                                    output = "<br><table>"
                                    output += "<tr><td>Artist:</td><td>#{current.artist}</td></tr>" if !current.artist.nil?
                                    output += "<tr><td>Title:</td><td>#{current.title}</td></tr>" if !current.title.nil?
                                    output += "<tr><td>Album:</td><td>#{current.album}</td></tr>" if !current.album.nil?
                                    output += "<tr><td>Source:</td><td>#{current.file}</td></tr>" if ( !current.file.nil? ) && ( current.album.nil? ) && ( current.artist.nil? )
                                    output += "</table><br>" + @infotemplate
                                    @@bot[:cli].set_comment(image+output)
                               rescue NoMethodError
                                    if @@bot[:debug]
                                        puts "#{$!}"
                                    end
                                end
                            else
                                if current.artist.nil? && current.title.nil? && current.album.nil?
                                    channelmessage( "#{current.file}") if @@bot[:chan_notify] && 0x80
                                else
                                    channelmessage( "#{current.artist} - #{current.title} (#{current.album})") if (@@bot[:chan_notify] && 0x80) != 0
                                end
                            end
                            lastcurrent = current
                            puts "[displayinfo] update" if @@bot[:debug]
                        end
                    end
                end
            end

            @@bot[:cli].on_user_state do |msg|
            end

            @@bot[:mpd].volume = @@bot[:initial_volume] if @@bot[:initial_volume] != nil
        end

        return @@bot
    end
    
    def name
        if @@bot[:messages] == nil
            "false"
        else
            self.class.name
        end
    end

    def help(h)
        h += "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
        h += "<b>#{@@bot[:controlstring]}settings</b> - Print current MPD settings.<br>"
        h += "<b>#{@@bot[:controlstring]}seek <i>value</i> | <i>+/-value</i></b> - Seek to an absolute position (in seconds). Use +value or -value to seek relative to the current position.<br>"
        h += "<b>#{@@bot[:controlstring]}seek <i>mm:ss</i> | <i>+/-mm:ss</i></b> - Seek to an absolute position. Use + or - to seek relative to the current position.<br>"
        h += "<b>#{@@bot[:controlstring]}seek <i>hh:mm:ss</i> | <i>+/-hh:mm:ss</i></b> - Seek to an absolute position. Use + or - to seek relative to the current position.<br>"
        h += "<b>#{@@bot[:controlstring]}crossfade <i>value</i></b> - Set Crossfade to value seconds, 0 to disable crossfading.<br>"
        h += "<b>#{@@bot[:controlstring]}next</b> - Play next title in the queue.<br>"
        h += "<b>#{@@bot[:controlstring]}prev</b> - Play previous title in the queue.<br>"
        h += "<b>#{@@bot[:controlstring]}clear</b> - Clear the playqueue.<br>"
        h += "<b>#{@@bot[:controlstring]}random</b> - Toggle random mode.<br>"
        h += "<b>#{@@bot[:controlstring]}single</b> - Toggle single mode.<br>"
        h += "<b>#{@@bot[:controlstring]}repeat</b> - Toggle repeat mode.<br>"
        h += "<b>#{@@bot[:controlstring]}consume</b> - Toggle consume mode. If this mode is enabled, songs will be removed from the play queue once they were played.<br>"
        h += "<b>#{@@bot[:controlstring]}pp</b> - Toggle pause/play.<br>"
        h += "<b>#{@@bot[:controlstring]}stop</b> - Stop playing.<br>"
        h += "<b>#{@@bot[:controlstring]}play</b> - Start playing.<br>"
        h += "<b>#{@@bot[:controlstring]}play <i>number</i></b> - Play title on position <i>number</i> in queue.<br>"
        h += "<b>#{@@bot[:controlstring]}songlist</b> - Print the list of ALL songs in the MPD collection.<br>"
        h += "<b>#{@@bot[:controlstring]}playlist <i>id</i></b> - Load the playlist referenced by the id.<br>"
        h += "<b>#{@@bot[:controlstring]}saveplaylist <i>name</i></b> - Save queue into a playlist named 'name'<br>"
        h += "<b>#{@@bot[:controlstring]}delplaylist <i>id</i></b> - Remove a playlist with the given id. Use #{@@bot[:controlstring]}playlists to get a list of available playlists.<br>"
        h += "<b>#{@@bot[:controlstring]}song</b> - Print some information about the currently played song.<br>"
        h += "<b>#{@@bot[:controlstring]}status</b> - Print current status of MPD.<br>"
        h += "<b>#{@@bot[:controlstring]}playlists</b> - Print the available playlists from MPD.<br>"
        h += "<b>#{@@bot[:controlstring]}add <i>searchstring</i></b> - Find song(s) by searchstring and print matches.<br>"
        h += "<b>#{@@bot[:controlstring]}where <i>searchstring</i></b> - Find song(s) by searchstring and print matches.<br>"
        h += "<b>#{@@bot[:controlstring]}queue</b> - Print the current play queue.<br>"
        h += "<b>#{@@bot[:controlstring]}stats</b> - Print some interesing MPD statistics.<br>"
        h += "<b>#{@@bot[:controlstring]}shuffle</b> – Play songs from the play queue in a random order.<br>"
        h += "<b>#{@@bot[:controlstring]}file</b> - Print the filename of the current song. This is useful if the file doesn't have ID3 tags and so the <b>#{@@bot[:controlstring]}song</b> command shows nothing.<br>"
        h += "<b>#{@@bot[:controlstring]}v++++</b> - Turns volume 20% up.<br>"
        h += "<b>#{@@bot[:controlstring]}v-</b> - Turns volume 5% down.<br>"
        h += "<b>#{@@bot[:controlstring]}v <i>value</i></b> - Set the volume to the given value.<br>"
        h += "<b>#{@@bot[:controlstring]}v</b> - Print the current playback volume.<br>"
        h += "<b>#{@@bot[:controlstring]}update</b> - Start a MPD database update.<br>"
        h += "<b>#{@@bot[:controlstring]}mpdconfig</b> - Try to read mpd config.<br>"
        h += "<b>#{@@bot[:controlstring]}mpdcommands</b> - Show what commands mpd do allow to Bot (not to you!).<br>"
        h += "<b>#{@@bot[:controlstring]}mpdnotcommands</b> - Show what commands mpd disallowed to Bot.<br>"
        h += "<b>#{@@bot[:controlstring]}mpddecoders</b> - Show enabled decoders and what they can decode for your mpd.<br>"
        
    end

    def handle_chat(msg,message)
        super
        if message == 'helpmpd'
            privatemessage( help(""))
        end
        
        if message[0..3] == 'seek'
            seekto = case message.count ":"
                when 0 then         # Seconds
                    0
                    if message.match(/^seek [+-]?[0-9]{1,3}$/)
                        result = message.match(/^seek ([+-]?[0-9]{1,3})$/)[1]
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
            rescue
                # mpd is old and knows no seek commands
                puts "[mpd-plugin] [error] seek without success, maybe mpd version < 0.17 installed"
            end
            status = @@bot[:mpd].status
            begin
                #Code from http://stackoverflow.com/questions/19595840/rails-get-the-time-difference-in-hours-minutes-and-seconds
                now_mm, now_ss = status[:time][0].divmod(60) #Minutes and seconds of current time within the song.
                now_hh, now_mm = now_mm.divmod(60)
                total_mm, total_ss = status[:time][1].divmod(60) #Minutes and seconds of total time of the song.
                total_hh, total_mm = total_mm.divmod(60)

                now = "%02d:%02d:%02d" % [now_hh, now_mm, now_ss]
                total = "%02d:%02d:%02d" % [total_hh, total_mm, total_ss]

                channelmessage( "Now on position #{now}/#{total}.")
            rescue
                channelmessage( "Sorry! Unknown stream position.")
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
            begin
                @@bot[:mpd].delete message.split(/ /)[1]
            rescue
                privatemessage( "Sorry, could not delete.")
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
            @@bot[:mpd].play
            @@bot[:cli].me.deafen false if @@bot[:cli].me.deafened?
            @@bot[:cli].me.mute false if @@bot[:cli].me.muted?
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
                    #messageto(msg.actor, out.to_s)
                    privatemessage(out.to_s)
                    out = ""
                    block = 0
                end
                out += "<br/>" + song.file.to_s
                block += 1
            end
            #messageto(msg.actor, out.to_s)
            privatemessage(out.to_s)    
        end

        if message == 'stats'
            out = "<table>"
            @@bot[:mpd].stats.each do |key, value|
                out += "<tr><td>#{key}</td><td>#{value}</td></tr>"
            end
            out += "</table>"
            privatemessage( out)    
        end

        if message == 'queue'
            if @@bot[:mpd].queue.length > 0
                text_out ="<table><th><td>#</td><td>Name</td></th>"
                songnr = 0
            
                @@bot[:mpd].queue.each do |song|
                    if song.title.to_s.empty?
                        text_out += "<tr><td>#{songnr}</td><td>No ID / Stream? Source: #{song.file}</td></tr>"
                    else
                        text_out += "<tr><td>#{songnr}</td><td>#{song.title}</td></tr>" 
                    end
                    songnr += 1
                end
                text_out += "</table>"
            else
                text_out = "The queue is empty."
            end
            
            privatemessage( text_out)
        end
        
        if message[0,12] == 'saveplaylist'
            name = message.gsub("saveplaylist", "").lstrip
            if name != ""
                puts name
                playlist = MPD::Playlist.new(@@bot[:mpd], name)
                @@bot[:mpd].queue.each do |song|
                    playlist.add song
                end

                privatemessage( "The playlist \"#{name}\" was created.
                                 Use the command #{@controlstring}playlists to get a list of all available playlists." )
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
            search = message.gsub("where", "").lstrip
            text_out = "you should search not nothing!"
            if search != ""
                text_out ="found:<br/>"
                @@bot[:mpd].where(any: "#{search}").each do |song|
                    text_out += "#{song.file}<br/>" 
                end
            end
            privatemessage( text_out)
        end

        if ( message[0,3] == 'add' ) 
            search = (message.gsub("add", "").lstrip).tr('"','')
            text_out = "search is empty"
            if search != ""
                text_out ="added:<br/>"
                count = 0
                @@bot[:mpd].where(any: "#{search}").each do |song|
                    text_out += "add #{song.file}<br/>" 
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
            @@bot[:mpd].playlists.each do |playlist|
                text_out = text_out + "#{counter} - #{playlist.name}<br/>"
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
                out += "<tr><td>#{key}</td><td>#{value}</td></tr>"
            end
            out += "</table>"
            privatemessage( out)    
        end

       if message == 'file'
            current = @@bot[:mpd].current_song
            privatemessage( "Filename of currently played song:<br>#{current.file}</span>") if not current.nil?
        end

        if message == 'song'
            current = @@bot[:mpd].current_song
            if not current.nil? #Would crash if playlist was empty.
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
            privatemessage( "running database update.")
        end
        
        if message == 'displayinfo'
            begin
                if @@bot[:use_comment_for_status_display] == true
                    @@bot[:use_comment_for_status_display] = false
                    privatemessage( "Output is now \"Channel\"")
                    @@bot[:cli].set_comment(@template_if_comment_disabled % [@controlstring])
                else
                    @@bot[:use_comment_for_status_display] = true
                    privatemessage( "Output is now \"Comment\"")
                    @@bot[:cli].set_comment(@template_if_comment_enabled)
                end
            rescue NoMethodError
                if @@bot[:debug]
                    puts "#{$!}"
                end
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
                output += "<br>#{command}"
            end
            privatemessage( output)
        end

        if message == 'mpdnotcommands'
            output = ""
            @@bot[:mpd].notcommands.each do |command| 
                output += "<br\>#{command}"
            end
            privatemessage( output)
        end

        if message == 'mpdurlhandlers'
            output = ""
            @@bot[:mpd].url_handlers.each do |handler| 
                output += "<br\>#{handler}"
            end
            privatemessage( output)
        end

        if message == 'mpddecoders'
            output = "<table>"
            @@bot[:mpd].decoders.each do |decoder| 
                output += "<tr>"
                output += "<td>#{decoder[:plugin]}</td>"
                output += "<td>"
                begin
                decoder[:suffix].each do |suffix|
                    output += "#{suffix} "
                end
                output += "</td>"
                rescue
                    output += "#{decoder[:suffix]}"
                end
            end
            output += "</table>"
            privatemessage( output)
        end

        
    end
end
