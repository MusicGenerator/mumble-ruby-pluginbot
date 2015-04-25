class Youtube < Plugin

    def init(init)
        @bot = init
        @downloadfolder = "../music/download/"
        @songlist = Queue.new
        @globalsonglist = Hash.new
    end

    def help(help)
        help += "<b>#{cc}http-link</b> will try to get some music from link.<br />"
        help += "<b>#{cc}yts keywords</b> will search on youtube for keywords"
        help += "<b>#{cc}yta</b> testing (not fix usage)"
    end

    def handle_chat(msg, message)
        if message.start_with?("<a href=") then
            link = msg.message[msg.message.index('>') + 1 .. -1]
            link = link[0..link.index('<')-1]
            workingdownload = Thread.new {
                #local variables for this thread!
                actor = msg.actor
                @bot[:cli].text_user(actor, "inspecting link: " + link + "...")
                get_song link
                if ( @songlist.size > 0 ) then
                    @bot[:mpd].update("download") 
                    @bot[:cli].text_user(actor, "Waiting for database update complete...")
                    
                    #Caution! following command needs patched ruby-mpd!
                    @bot[:mpd].idle("update")
                    # find this lines in ruby-mpd/plugins/information.rb (actual 47-49)
                    # def idle(*masks)
                    #  send_command(:idle, *masks)
                    # end
                    # and uncomment it there, then build gem new.
                        
                    @bot[:cli].text_user(actor, "Update done.")
                    while @songlist.size > 0 
                        song = @songlist.pop
                        @bot[:cli].text_user(actor, song)
                        @bot[:mpd].add("download/"+song)
                        sleep 0.5
                    end
                else
                    @bot[:cli].text_user(actor, "The link contains nothing interesting for me.")
                end
            }
        end
        
        if message.split[0] == 'yts'
            search = ""
            message.split[1..-1].each do |keyword|
                search += search + "+" + keyword
            end
            puts search[1..-1]
            songs = find_youtube_song(search[1..-1])
            out = "<table>"
            songs.each do |song, index| 
                out += "<tr><td><b>#{index}</b></td><td>#{song}</td></tr>"
            end
            out += "</table>"
            @bot[:cli].text_user(msg.actor, out)    
        end

        if message.split[0] == 'yta'
            link = "https://www.youtube.com/watch?v="+message.split[1].to_s
            workingdownload = Thread.new {
                #local variables for this thread!
                actor = msg.actor
                @bot[:cli].text_user(actor, "inspecting link: " + link + "...")
                get_song link
                if ( @songlist.size > 0 ) then
                    @bot[:mpd].update("download") 
                    @bot[:cli].text_user(actor, "Waiting for database update complete...")
                    
                    #Caution! following command needs patched ruby-mpd!
                    @bot[:mpd].idle("update")
                    # find this lines in ruby-mpd/plugins/information.rb (actual 47-49)
                    # def idle(*masks)
                    #  send_command(:idle, *masks)
                    # end
                    # and uncomment it there, then build gem new.
                        
                    @bot[:cli].text_user(actor, "Update done.")
                    while @songlist.size > 0 
                        song = @songlist.pop
                        @bot[:cli].text_user(actor, song)
                        @bot[:mpd].add("download/"+song)
                        sleep 0.5
                    end
                else
                    @bot[:cli].text_user(actor, "The link contains nothing interesting for me.")
                end
            }
        end
    end

    def find_youtube_song song
        songlist = Hash.new
        songs = `/usr/local/bin/youtube-dl --get-title --get-id "https://www.youtube.com/results?search_query=#{song}"`
        songlist = Hash[*songs.split(/\n/)]
        @globalsonglist = @globalsonglist.merge(songlist)
        return songlist
    end

    def get_song(site)
        if ( site.include? "www.youtube.com/" ) || ( site.include? "www.youtu.be/" ) || ( site.include? "m.youtube.com/" ) then
            site.gsub!(/<\/?[^>]*>/, '')
            site.gsub!("&amp;", "&")
            filename = `/usr/local/bin/youtube-dl --get-filename -r 2.5M -i -o \"#{@downloadfoler}%(title)s\" "#{site}"`
            system ("/usr/local/bin/youtube-dl -i -o \"#{@downloadfolder}%(title)s.%(ext)s\" \"#{site}\" ")
            filename.split("\n").each do |name|
                system ("if [ ! -e \"#{@downloadfolder}#{name}.mp3\" ]; then ffmpeg -i \"#{@downloadfolder}#{name}.mp4\" -q:a 0 -map a -metadata title=\"#{name}\" \"#{@downloadfolder}#{name}.mp3\" -y; fi")
                system ("if [ ! -e \"#{@downloadfolder}#{name}.jpg\" ]; then ffmpeg -i \"#{@downloadfolder}#{name}.mp4\" -s qvga -filter:v select=\"eq(n\\,250)\" -vframes 1 \"#{@downloadfolder}#{name}.jpg\" -y; fi")
                @songlist << name.split("/")[-1] + ".mp3"
            end
        end
    end

end