class Youtube < Plugin

    def init(init)
        @bot = init
        if ( @bot[:mpd] != nil ) && ( @bot[:messages] != nil ) && ( @bot[:youtube] == nil )
            begin
                @youtubefolder = @bot[:mpd_musicfolder] + @bot[:youtube_downloadsubdir]
                @tempyoutubefolder = @bot[:main_tempdir] + @bot[:youtube_tempsubdir]
            rescue
                puts "Error: Youtube-Plugin doesn't found settings for mpd music directory and/or your preferred temporary download directory"
                puts "See pluginbot_conf.rb"
            end
            @songlist = Queue.new
            @keylist = Array.new
            @bot[:youtube] = self
        end
        return @bot
    end

    def name
        if ( @bot[:mpd] == nil ) || ( @bot[:youtube] == nil)
            "false"
        else    
            self.class.name
        end
    end

    def help(h)
        h += "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br />"
        h += "<b>#{@bot[:controlstring]}ytlink <i>URL</i></b> - Will try to download the music from the given URL.<br />"
        h += "<b>#{@bot[:controlstring]}yts keywords</b> - Will search on Youtube for one or more keywords and print the results to you.<br />"
        h += "<b>#{@bot[:controlstring]}yta <i>number</i></b> - Let the bot download the given song from the list you got via <i>#{@bot[:controlstring]}yts</i>.<br />Instead of a specific numer, write <b>#{@bot[:controlstring]}yta <i>all</i></b> to let the bot download all found songs."
    end

    def handle_chat(msg, message)
        if message.start_with?("ytlink <a href=") || message.start_with?("<a href=") then
            link = msg.message[msg.message.index('>') + 1 .. -1]
            link = link[0..link.index('<')-1]
            workingdownload = Thread.new {
                #local variables for this thread!
                actor = msg.actor
                @bot[:messages].text(actor, "inspecting link: " + link + "...")
                if @bot[:youtube_to_mp3] != nil
                    get_song_mp3 link
                else
                    get_song link
                end
                if ( @songlist.size > 0 ) then
                    @bot[:mpd].update(@bot[:youtube_downloadsubdir].gsub(/\//,"")) 
                    @bot[:messages].text(actor, "Waiting for database update complete...")
                    
                    begin
                        #Caution! following command needs patched ruby-mpd!
                        @bot[:mpd].idle("update")
                        # find this lines in ruby-mpd/plugins/information.rb (actual 47-49)
                        # def idle(*masks)
                        #  send_command(:idle, *masks)
                        # end
                        # and uncomment it there, then build gem new.
                    rescue
                        puts "[youtube-plugin] [info] idle-patch of ruby-mpd not implemented. Sleeping 10 seconds." if @bot[:debug]
                        sleep 10
                    end
                        
                    @bot[:messages].text(actor, "Update done.")
                    while @songlist.size > 0 
                        song = @songlist.pop
                        @bot[:messages].text(actor, song)
                        @bot[:mpd].add(@bot[:youtube_downloadsubdir]+song)
                    end
                else
                    @bot[:messages].text(actor, "The link contains nothing interesting for me.") if @bot[:youtube_stream] == nil
                end
            }
        end
        
        if message.split[0] == 'yts'
            search = message[4..-1]
            if !(( search == nil ) || ( search == "" ))
                workingsearch = Thread.new {
                    search.gsub!(" ", "+")
                    search.gsub!(/"/, "")
                    @bot[:messages].text(msg.actor, "searching for #{search}, please be patient...")    
                    songs = find_youtube_song(search)
                    @keylist[msg.actor] = songs
                    index = 0
                    out = ""
                    @keylist[msg.actor].each do |id , title|
                        if ( ( index % 30 ) == 0 )
                            @bot[:messages].text(msg.actor, out + "</table>") if index != 0   
                            out = "<table><tr><td><b>Index</b></td><td>Title</td></tr>"
                        end
                        out += "<tr><td><b>#{index}</b></td><td>#{title}</td></tr>"
                        index += 1
                    end
                    out +="</table>"
                    @bot[:messages].text(msg.actor, out)    
                }
            else    
                @bot[:messages].text(msg.actor, "won't search for nothing!")    
            end
        end

        if message.split[0] == 'yta'
            begin
                link = []
                if message.split[1] != "all"
                    downloadid = @keylist[msg.actor][message.split[1].to_i]
                    @bot[:messages].text(msg.actor, "adding #{downloadid[1]}")    
                    link << "https://www.youtube.com/watch?v="+downloadid[0]
                else
                    out = ""
                    @keylist[msg.actor].each do |downloadid|
                        out += "adding #{downloadid[1]}<br />"
                        link << "https://www.youtube.com/watch?v="+downloadid[0]
                    end
                    @bot[:messages].text(msg.actor, out)    
                end
                workingdownload = Thread.new {
                    #local variables for this thread!
                    actor = msg.actor
                    @bot[:messages].text(actor, "do #{link.length.to_s} time(s)...")    
                    link.each do |l| 
                        @bot[:messages].text(actor, "fetch and convert")
                        if @bot[:youtube_to_mp3] != nil
                            get_song_mp3 l
                        else
                            get_song l
                        end
                    end
                    if ( @songlist.size > 0 ) then
                        @bot[:mpd].update(@bot[:youtube_downloadsubdir].gsub(/\//,"")) 
                        @bot[:messages].text(actor, "Waiting for database update complete...")
                        
                        begin
                            #Caution! following command needs patched ruby-mpd!
                            @bot[:mpd].idle("update")
                            # find this lines in ruby-mpd/plugins/information.rb (actual 47-49)
                            # def idle(*masks)
                            #  send_command(:idle, *masks)
                            # end
                            # and uncomment it there, then build gem new.
                        rescue
                            puts "[youtube-plugin] [info] idle-patch of ruby-mpd not implemented. Sleeping 10 seconds." if @bot[:debug]
                            sleep 10
                        end
                        @bot[:messages].text(actor, "Update done.")
                        out = "<b>Added:</b><br />"
                        while @songlist.size > 0 
                            song = @songlist.pop
                            begin
                                @bot[:mpd].add(@bot[:youtube_downloadsubdir]+song)
                                out += song + "<br />"
                            rescue
                                out += "fixme: " + song + " not found!<br />"
                            end
                        end
                        @bot[:messages].text(actor, out)
                    else
                        @bot[:messages].text(actor, "The link contains nothing interesting for me.") if @bot[:youtube_stream] == nil
                    end
                }
            rescue
                @bot[:messages].text(msg.actor, "[error](youtube-plugin)- index number is out of bounds!")    
            end
        end
    end

    def find_youtube_song song
        songlist = []
        songs = `#{@bot[:youtube_youtubedl]} --get-title --get-id "https://www.youtube.com/results?search_query=#{song}"`
        temp = songs.split(/\n/)
        while (temp.length >= 2 )
            songlist << [temp.pop , temp.pop]
        end
        return songlist
    end

    def get_song(site)
        if ( site.include? "www.youtube.com/" ) || ( site.include? "www.youtu.be/" ) || ( site.include? "m.youtube.com/" ) then
            site.gsub!(/<\/?[^>]*>/, '')
            site.gsub!("&amp;", "&")
            if @bot[:youtube_stream] == nil
                filename = `#{@bot[:youtube_youtubedl]} --get-filename --restrict-filenames -r 2.5M -i -o \"#{@tempdownloadfoler}%(title)s\" "#{site}"`
                system ("nice -n20 #{@bot[:youtube_youtubedl]} --restrict-filenames -r 2.5M --write-thumbnail -x --audio-format m4a -o \"#{@tempyoutubefolder}%(title)s.%(ext)s\" \"#{site}\" ")     #get icon
                filename.split("\n").each do |name|
                    system ("convert \"#{@tempyoutubefolder}#{name}.jpg\" -resize 320x240 \"#{@youtubefolder}#{name}.jpg\" ")
                    system ("if [ ! -e \"#{@youtubefolder}#{name}.m4a\" ]; then ffmpeg -i \"#{@tempyoutubefolder}#{name}.m4a\" -acodec copy -metadata title=\"#{name}\" \"#{@youtubefolder}#{name}.m4a\" -y; fi") 
                    @songlist << name.split("/")[-1] + ".m4a" 
                end
            else
                streams = `youtube-dl -g "#{site}"`
                streams.each_line do |line|
                    line.chop!
                    @bot[:mpd].add line if line.include? "mime=audio/mp4"
                end
            end
        end
    end
    
    def get_song_mp3(site)
        if ( site.include? "www.youtube.com/" ) || ( site.include? "www.youtu.be/" ) || ( site.include? "m.youtube.com/" ) then
            site.gsub!(/<\/?[^>]*>/, '')
            site.gsub!("&amp;", "&")
            if @bot[:youtube_stream] == nil
                filename = `#{@bot[:youtube_youtubedl]} --get-filename --restrict-filenames -r 2.5M -i -o \"#{@tempdownloadfoler}%(title)s\" "#{site}"`
                system ("nice -n20 #{@bot[:youtube_youtubedl]} --restrict-filenames -r 2.5M --write-thumbnail -x --audio-format mp3 -o \"#{@tempyoutubefolder}%(title)s.%(ext)s\" \"#{site}\" ")     #get icon
                filename.split("\n").each do |name|
                    system ("convert \"#{@tempyoutubefolder}#{name}.jpg\" -resize 320x240 \"#{@youtubefolder}#{name}.jpg\" ")
                    system ("if [ ! -e \"#{@youtubefolder}#{name}.mp3\" ]; then ffmpeg -i \"#{@tempyoutubefolder}#{name}.mp3\" -acodec copy -metadata title=\"#{name}\" \"#{@youtubefolder}#{name}.mp3\" -y; fi") 
                    @songlist << name.split("/")[-1] + ".mp3" 
                end
            else
                streams = `youtube-dl -g "#{site}"`
                streams.each_line do |line|
                    line.chop!
                    @bot[:mpd].add line if line.include? "mime=audio/m4a"
                end
            end
        end
    end

end
