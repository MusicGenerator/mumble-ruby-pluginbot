# a pluginbot plugin

class Mpd < Plugin
    
    def init(init)
        @bot = init
    end

    def help(h)
        h += "<hr><span style='color:red;'>Plugin MPD</span><br />"
        h += "<b>#{@bot[:controlstring]}settings</b> display current settings.<br />"
        h += "<b>#{@bot[:controlstring]}seek <i>value</i>|<i>+/-value</i></b> Seek to an absolute position (in seconds). Use +value or -value to seek relative to the current position.<br />"
        h += "<b>#{@bot[:controlstring]}crossfade <i>value</i></b> Set Crossfade to value seconds, 0 to disable this.<br />"
        h += "<b>#{@bot[:controlstring]}next</b> Play next title.<br />"
        h += "<b>#{@bot[:controlstring]}prev</b> Play previous title.<br />"
        h += "<b>#{@bot[:controlstring]}clear</b> Clear playqueue.<br />"
        h += "<b>#{@bot[:controlstring]}random</b> toggle random mode.<br />"
        h += "<b>#{@bot[:controlstring]}single</b> toggle single mode.<br />"
        h += "<b>#{@bot[:controlstring]}repeat</b> toggle repeat mode.<br />"
        h += "<b>#{@bot[:controlstring]}consume</b> toggle consume mode.<br />"
        h += "<b>#{@bot[:controlstring]}pp</b> toggle pause/play.<br />"
        h += "<b>#{@bot[:controlstring]}stop</b> Stop playing.<br />"
        h += "<b>#{@bot[:controlstring]}play</b> Start playing.<br />"
        h += "<b>#{@bot[:controlstring]}songlist</b> Display songlist.<br />"
        h += "<b>#{@bot[:controlstring]}playlist <i>value</i></b> load playlist.<br />"
        h += "<b>#{@bot[:controlstring]}song</b> Display songname.<br />"
        h += "<b>#{@bot[:controlstring]}status</b> Display current status.<br />"
        h += "<b>#{@bot[:controlstring]}playlists</b> Display playlists.<br />"
        h += "<b>#{@bot[:controlstring]}add song</b> find song by name and display matches.<br />"
        h += "<b>#{@bot[:controlstring]}where song</b> find song by name and display matches.<br />"
        h += "<b>#{@bot[:controlstring]}queue</b> Display actual queue.<br />"
        h += "<b>#{@bot[:controlstring]}stats</b> Display player stats.<br />"
        h += "<b>#{@bot[:controlstring]}shuffle</b> Shuffle play queue.<br />"
        h += "<b>#{@bot[:controlstring]}file</b> Display filename.<br />"
        h += "<b>#{@bot[:controlstring]}v++++</b> turns volume 20% up.<br />"
        h += "<b>#{@bot[:controlstring]}v-</b> turns volume 5% down.<br />"
        h += "<b>#{@bot[:controlstring]}v <i>value</i></b> Set playback volume to value.<br />"
        h += "<b>#{@bot[:controlstring]}v</b> Info about current playback volume.<br />"
    end

    def handle_chat(msg,message)
        if message == 'helpmpd'
            @bot[:cli].text_user(msg.actor, help(""))
        end
        if message.match(/^seek [+-]?[0-9]{1,3}$/)
            seekto = message.match(/^seek ([+-]?[0-9]{1,3})$/)[1]
            @bot[:mpd].seek seekto
            status = @bot[mpd].status

            #Code from http://stackoverflow.com/questions/19595840/rails-get-the-time-difference-in-hours-minutes-and-seconds
            now_mm, now_ss = status[:time][0].divmod(60) #Minutes and seconds of current time within the song.
            now_hh, now_mm = now_mm.divmod(60)
            total_mm, total_ss = status[:time][1].divmod(60) #Minutes and seconds of total time of the song.
            total_hh, total_mm = total_mm.divmod(60)

            now = "%02d:%02d:%02d" % [now_hh, now_mm, now_ss]
            total = "%02d:%02d:%02d" % [total_hh, total_mm, total_ss]

            @bot[cli].text_channel(@bot[:cli].me.current_channel, "Seeked to position #{now}/#{total}.")
        end

        if message.match(/^crossfade [0-9]{1,3}$/)
            secs = message.match(/^crossfade ([0-9]{1,3})$/)[1].to_i
            @bot[mpd].crossfade = secs
        end

        @bot[:mpd].next if message == 'next'
        @bot[:mpd].previous if message == 'prev'

        if message == 'clear'
            @bot[:mpd].clear
            @bot[:cli].text_user(msg.actor, "The playqueue was cleared.")
        end

        if message == 'random'
            @bot[:mpd].random = !@bot[:mpd].random?
        end

        if message == 'repeat'
            @bot[:mpd].repeat = !@bot[:mpd].repeat?
        end

        if message == 'single'
            @bot[:mpd].single = !@bot[:mpd].single?
        end

        if message == 'consume'
            @bot[:mpd].consume = !@bot[:mpd].consume?
        end

        if message == 'pp'
            @bot[:mpd].pause = !@bot[:mpd].paused?
        end

        @bot[:mpd].stop if message == 'stop'

        if message == 'play'
            @bot[:mpd].play
            @bot[:cli].me.deafen false
            @bot[:cli].me.mute false
        end

        if message == 'songlist'
            block = 0
            out = ""
            @bot[:mpd].songs.each do |song|
                if block >= 50
                    @bot[:cli].text_user(msg.actor, out)
                    out = ""
                    block = 0
                end
                out += "<br/>" + song.file
                block += 1
            end
            @bot[:cli].text_user(msg.actor, out)    
        end

        if message == 'stats'
            out = "<table>"
            @bot[:mpd].stats.each do |key, value|
                out += "<tr><td>#{key}</td><td>#{value}</td></tr>"
            end
            out += "</table>"
            @bot[:cli].text_user(msg.actor, out)    
        end

        if message == 'queue'
            text_out ="<br/>"
            @bot[:mpd].queue.each do |song|
                text_out += "#{song.title}<br/>" 
            end
            @bot[:cli].text_user(msg.actor, text_out)
        end

        if ( message[0,5] == 'where' ) 
            search = message.gsub("where", "").lstrip
            text_out = "you should search not nothing!"
            if search != ""
                text_out ="found:<br/>"
                @bot[:mpd].where(any: "#{search}").each do |song|
                    text_out += "#{song.file}<br/>" 
                end
            end
            @bot[:cli].text_user(msg.actor, text_out)
        end

        if ( message[0,3] == 'add' ) 
            search = message.gsub("add", "").lstrip
            text_out = "nothing found/added!"
            if search != ""
                text_out ="added:<br/>"
                @bot[:mpd].where(any: "#{search}").each do |song|
                    text_out += "add #{song.file}<br/>" 
                    @bot[:mpd].add(song)
                end
            end
            @bot[:cli].text_user(msg.actor, text_out)
        end

        if message == 'playlists'
            text_out = ""
            counter = 0
            @bot[:mpd].playlists.each do |playlist|
                text_out = text_out + "#{counter} - #{playlist.name}<br/>"
                counter += 1
            end
            @bot[:cli].text_user(msg.actor, "I know the following playlists:<br />#{text_out}")
        end

        if message.match(/^playlist [0-9]{1,3}.*$/)
            playlist_id = message.match(/^playlist ([0-9]{1,3})$/)[1].to_i
            begin
                playlist = @bot[:mpd].playlists[playlist_id]
                @bot[:mpd].clear
                playlist.load
                @bot[:mpd].play
                @bot[:cli].text_user(msg.actor, "The playlist \"#{playlist.name}\" was loaded and starts now.")
            rescue
                @bot[:cli].text_user(msg.actor, "Sorry, the given playlist id does not exist.")
            end
        end

        if message == 'status' 
            out = "<table>"
            @bot[:mpd].status.each do |key, value|
                out += "<tr><td>#{key}</td><td>#{value}</td></tr>"
            end
            out += "</table>"
            @bot[:cli].text_user(msg.actor, out)    
        end

       if message == 'file'
            current = @bot[:mpd].current_song
            @bot[:cli].text_user(msg.actor, "Filename of currently played song:<br />#{current.file}</span>") if not current.nil?
        end

        if message == 'song'
            current = @bot[:mpd].current_song
            if not current.nil? #Would crash if playlist was empty.
                @bot[:cli].text_user(msg.actor, "#{current.artist} - #{current.title} (#{current.album})")
            else
                @bot[:cli].text_user(msg.actor, "No song is played currently.")
            end
        end

        if message == 'shuffle'
            @bot[:mpd].shuffle
            @bot[:cli].text_user(msg.actor, "Shuffle, shuffle and get a new order. :)")
        end

        if message == 'v'
            volume = @bot[:mpd].volume
            @bot[:cli].text_user(msg.actor, "Current volume is #{volume}%.")
        end    

        if message.match(/^v [0-9]{1,3}$/)
            volume = message.match(/^v ([0-9]{1,3})$/)[1].to_i
            
            if (volume >=0 ) && (volume <= 100)
                @bot[:mpd].volume = volume
            else
                @bot[:cli].text_user(msg.actor, "Volume can be within a range of 0 to 100")
            end
        end

        if message.match(/^v[-]+$/)
            multi = message.match(/^v([-]+)$/)[1].scan(/\-/).length
            volume = ((@bot[:mpd].volume).to_i - 5 * multi)
            if volume < 0
                @bot[:cli].text_channel(@bot[:cli].me.current_channel, "Volume can't be set to &lt; 0.")
                volume = 0
            end
            @bot[:mpd].volume = volume
        end

        if message.match(/^v[+]+$/)
            multi = message.match(/^v([+]+)$/)[1].scan(/\+/).length
            volume = ((@bot[:mpd].volume).to_i + 5 * multi)
            if volume > 100
                @bot[:cli].text_channel(@bot[:cli].me.current_channel, "Volume can't be set to &gt; 100.")
                volume = 100
            end
            @bot[:mpd].volume = volume
        end
    end
end