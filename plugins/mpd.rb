# a pluginbot plugin

class Mpd < Plugin
    
    def init(init)
        @bot = init
    end

    def help(help)
        cc= @bot[:controlstring]
        help += "<b>#{cc}settings</b> display current settings.<br />"
        help += "<b>#{cc}seek <i>value</i>|<i>+/-value</i></b> Seek to an absolute position (in seconds). Use +value or -value to seek relative to the current position.<br />"
        help += "<b>#{cc}crossfade <i>value</i></b> Set Crossfade to value seconds, 0 to disable this.<br />"
        help += "<b>#{cc}next</b> Play next title.<br />"
        help += "<b>#{cc}prev</b> Play previous title.<br />"
        help += "<b>#{cc}clear</b> Clear playqueue.<br />"
        help += "<b>#{cc}random</b> toggle random mode.<br />"
        help += "<b>#{cc}single</b> toggle single mode.<br />"
        help += "<b>#{cc}repeat</b> toggle repeat mode.<br />"
        help += "<b>#{cc}consume</b> toggle consume mode.<br />"
        help += "<b>#{cc}pp</b> toggle pause/play.<br />"
        help += "<b>#{cc}stop</b> Stop playing.<br />"
        help += "<b>#{cc}play</b> Start playing.<br />"
        help += "<b>#{cc}songlist</b> Display songlist.<br />"
        help += "<b>#{cc}playlist <i>value</i></b> load playlist.<br />"
        help += "<b>#{cc}song</b> Display songname.<br />"
        help += "<b>#{cc}status</b> Display current status.<br />"
        help += "<b>#{cc}playlists</b> Display playlists.<br />"
        help += "<b>#{cc}add song</b> find song by name and display matches.<br />"
        help += "<b>#{cc}where song</b> find song by name and display matches.<br />"
        help += "<b>#{cc}queue</b> Display actual queue.<br />"
        help += "<b>#{cc}stats</b> Display player stats.<br />"
        help += "<b>#{cc}file</b> Display filename.<br />"
        help += "<b>#{cc}v++++</b> turns volume 20% up.<br />"
        help += "<b>#{cc}v-</b> turns volume 5% down.<br />"
        help += "<b>#{cc}v <i>value</i></b> Set playback volume to value.<br />"
        help += "<b>#{cc}v</b> Info about current playback volume.<br />"
    end

    def handle_chat(msg,message)
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
    end
end