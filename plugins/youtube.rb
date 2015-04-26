class Youtube < Plugin

    def init(init)
        @bot = init
        @downloadfolder = "../music/download/"
        @songlist = Queue.new
        @keylist = Array.new
        @titlelist = Hash.new
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
            search = message[4..-1]
            search.gsub!(" ", "+") 
            search = "" if search == nil
            songs = find_youtube_song(search)
            @keylist[msg.actor] = songs
            out = "<table><tr><td><b>Index</b></td><td>Title</td></tr>"
            index = 0
            @keylist[msg.actor].each do |id , title|
                out += "<tr><td><b>#{index}</b></td><td>#{title}</td></tr>"
                index += 1
            end
            out +="</table>"
            @bot[:cli].text_user(msg.actor, out)    
        end

        if message.split[0] == 'yta'
            begin
                link = []
                if message.split[1] != "all"
                    downloadid = @keylist[msg.actor][message.split[1].to_i]
                    @bot[:cli].text_user(msg.actor, "adding #{downloadid[1]}")    
                    link << "https://www.youtube.com/watch?v="+downloadid[0]
                else
                    out = ""
                    @keylist[msg.actor].each do |downloadid|
                        out += "adding #{downloadid[1]}<br />"
                        link << "https://www.youtube.com/watch?v="+downloadid[0]
                    end
                    @bot[:cli].text_user(msg.actor, out)    
                end
                workingdownload = Thread.new {
                    #local variables for this thread!
                    actor = msg.actor
                    @bot[:cli].text_user(actor, "start fetching.")    
                    link.each { |l| get_song l}
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
                        out = "<b>Added:</b><br />"
                        while @songlist.size > 0 
                            song = @songlist.pop
                            out += song + "<br />"
                            @bot[:mpd].add("download/"+song)
                        end
                        @bot[:cli].text_user(actor, out)
                    else
                        @bot[:cli].text_user(actor, "The link contains nothing interesting for me.")
                    end
                }
            rescue
                @bot[:cli].text_user(msg.actor, "[error](youtube-plugin)- index number is out of bounds!")    
            end
        end
    end

    def find_youtube_song song
        songlist = []
        songs = `/usr/local/bin/youtube-dl --get-title --get-id "https://www.youtube.com/results?search_query=#{song}"`
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