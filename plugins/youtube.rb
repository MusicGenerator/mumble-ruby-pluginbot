class Youtube < Plugin

    def init(init)
        @bot = init
        if ( @bot[:mpd] != nil ) && ( @bot[:youtube] == nil )
            @downloadfolder = "../music/download/"                          # will move into config soon
            @tempdownloadfolder = "./temp/download/"                        # will move into config soon
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
        h += "<hr><span style='color:red;'>Plugin YOUTUBE</span><br />"
        h += "<b>#{@bot[:controlstring]}http-link</b> will try to get some music from link.<br />"
        h += "<b>#{@bot[:controlstring]}yts keywords</b> will search on youtube for keywords.<br />"
        h += "<b>#{@bot[:controlstring]}yta <i>number</i> </b> get song in yts list.<br />"
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
                    
                    begin
                        #Caution! following command needs patched ruby-mpd!
                        @bot[:mpd].idle("update")
                        # find this lines in ruby-mpd/plugins/information.rb (actual 47-49)
                        # def idle(*masks)
                        #  send_command(:idle, *masks)
                        # end
                        # and uncomment it there, then build gem new.
                    rescue
                        sleep 10
                    end
                        
                    @bot[:cli].text_user(actor, "Update done.")
                    while @songlist.size > 0 
                        song = @songlist.pop
                        @bot[:cli].text_user(actor, song)
                        @bot[:mpd].add("download/"+song)
                    end
                else
                    @bot[:cli].text_user(actor, "The link contains nothing interesting for me.")
                end
            }
        end
        
        if message.split[0] == 'yts'
            search = message[4..-1]
            if !(( search == nil ) || ( search == "" ))
                @bot[:cli].text_user(msg.actor, "searching, please be patient...")    
                workingsearch = Thread.new {
                    search.gsub!(" ", "+")
                    songs = find_youtube_song(search)
                    @keylist[msg.actor] = songs
                    index = 0
                    out = ""
                    @keylist[msg.actor].each do |id , title|
                        if ( ( index % 30 ) == 0 )
                            @bot[:cli].text_user(msg.actor, out + "</table>") if index != 0   
                            out = "<table><tr><td><b>Index</b></td><td>Title</td></tr>"
                        end
                        out += "<tr><td><b>#{index}</b></td><td>#{title}</td></tr>"
                        index += 1
                    end
                    out +="</table>"
                    @bot[:cli].text_user(msg.actor, out)    
                }
            else    
                @bot[:cli].text_user(msg.actor, "won't search for nothing!")    
            end
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
                    @bot[:cli].text_user(actor, "do #{link.length.to_s} time(s)...")    
                    link.each do |l| 
                        @bot[:cli].text_user(actor, "fetch and convert")
                        get_song l
                    end
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
                            begin
                                @bot[:mpd].add("download/"+song)
                                out += song + "<br />"
                            rescue
                                out += "fixme: " + song + " not found!<br />"
                            end
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
            filename = `/usr/local/bin/youtube-dl --get-filename --restrict-filenames -r 2.5M -i -o \"#{@tempdownloadfoler}%(title)s\" "#{site}"`
            system ("/usr/local/bin/youtube-dl --restrict-filenames -r 2.5M --write-thumbnail -x --audio-format m4a -o \"#{@tempdownloadfolder}%(title)s.%(ext)s\" \"#{site}\" ")     #get icon
            filename.split("\n").each do |name|
                system ("convert \"#{@tempdownloadfolder}#{name}.jpg\" -resize 320x240 \"#{@downloadfolder}#{name}.jpg\" ")
                system ("if [ ! -e \"#{@downloadfolder}#{name}.m4a\" ]; then ffmpeg -i \"#{@tempdownloadfolder}#{name}.m4a\" -acodec copy -metadata title=\"#{name}\" \"#{@downloadfolder}#{name}.m4a\" -y; fi") 
                @songlist << name.split("/")[-1] + ".m4a" 
            end
        end
    end

end