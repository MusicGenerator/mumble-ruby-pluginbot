class Soundcloud < Plugin

    def init(init)
        @bot = init
        if ( @bot[:mpd] != nil ) && ( @bot[:messages] != nil ) && ( @bot[:soundcloud] == nil )
            begin
                @soundcloudfolder = @bot[:mpd_musicfolder] + @bot[:soundcloud_downloadsubdir]
                @tempsoundcloudfolder = @bot[:main_tempdir] + @bot[:soundcloud_tempsubdir]
            rescue
                puts "Error: soundcloud-Plugin doesn't found settings for mpd music directory and/or your preferred temporary download directory"
                puts "See pluginbot_conf.rb"
            end
            begin
                @ytdloptions = @bot[:soundcloud_youtubedl_options]
            rescue
                @ytdloptions = "" 
            end
            @songlist = Queue.new
            @keylist = Array.new
            @bot[:soundcloud] = self
        end
        @filetypes= ["ogg", "mp3", "mp2", "m4a", "aac", "wav", "ape", "flac"]
        return @bot
    end

    def name
        if ( @bot[:mpd] == nil ) || ( @bot[:soundcloud] == nil)
            "false"
        else    
            self.class.name
        end
    end

    def help(h)
        h += "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br />"
        h += "<b>#{@bot[:controlstring]}ytlink <i>URL</i></b> - Will try to download the music from the given URL.<br />"
        h += "<b>#{@bot[:controlstring]}yts keywords</b> - Will search on soundcloud for one or more keywords and print the results to you.<br />"
        h += "<b>#{@bot[:controlstring]}yta <i>number</i></b> - Let the bot download the given song from the list you got via <i>#{@bot[:controlstring]}yts</i>.<br />Instead of a specific numer, write <b>#{@bot[:controlstring]}yta <i>all</i></b> to let the bot download all found songs."
    end

    def handle_chat(msg, message)
        if message.start_with?("soundcloud <a href=") || message.start_with?("<a href=") then
            link = msg.message[msg.message.index('>') + 1 .. -1]
            link = link[0..link.index('<')-1]
            workingdownload = Thread.new {
                #local variables for this thread!
                actor = msg.actor
                @bot[:messages].text(actor, "Soundcloud is inspecting link: " + link + "...")
                get_song link
                if ( @songlist.size > 0 ) then
                    @bot[:mpd].update(@bot[:soundcloud_downloadsubdir].gsub(/\//,"")) 
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
                        puts "[soundcloud-plugin] [info] idle-patch of ruby-mpd not implemented. Sleeping 10 seconds." if @bot[:debug]
                        sleep 10
                    end
                        
                    @bot[:messages].text(actor, "Update done.")
                    while @songlist.size > 0 
                        song = @songlist.pop
                        @bot[:messages].text(actor, song)
                        @bot[:mpd].add(@bot[:soundcloud_downloadsubdir]+song)
                    end
                else
                    @bot[:messages].text(actor, "Soundcloud: The link contains nothing interesting.") if @bot[:soundcloud_stream] == nil
                end
            }
        end
    end

    def get_song(site)
        if ( site.include? "soundcloud.com/" ) then
            site.gsub!(/<\/?[^>]*>/, '')
            site.gsub!("&amp;", "&")
            puts site
            filename = `#{@bot[:soundcloud_youtubedl]} --get-filename #{@ytdloptions} -i -o \"#{@tempdownloadfoler}%(title)s\" "#{site}"`
            output =`nice -n20 #{@bot[:soundcloud_youtubedl]} #{@ytdloptions} --write-thumbnail -x --audio-format best -o \"#{@tempsoundcloudfolder}%(title)s.%(ext)s\" \"#{site}\" `     #get icon
            filename.split("\n").each do |name|
                @filetypes.each do |ending|
                    if File.exist?("#{@tempsoundcloudfolder}#{name}.#{ending}")
                        system ("nice -n20 convert \"#{@tempsoundcloudfolder}#{name}.jpg\" -resize 320x240 \"#{@soundcloudfolder}#{name}.jpg\" ")
                        if @bot[:soundcloud_to_mp3] == nil
                            # Mixin tags without recode on standard
                            system ("nice -n20 ffmpeg -i \"#{@tempsoundcloudfolder}#{name}.#{ending}\" -acodec copy -metadata title=\"#{name}\" \"#{@soundcloudfolder}#{name}.#{ending}\"") if !File.exist?("#{@soundcloudfolder}#{name}.#{ending}")
                            @songlist << name.split("/")[-1] + ".#{ending}"
                        else
                            # Mixin tags and recode it to mp3 (vbr 190kBit)
                            system ("nice -n20 ffmpeg -i \"#{@tempsoundcloudfolder}#{name}.#{ending}\" -codec:a libmp3lame -qscale:a 2 -metadata title=\"#{name}\" \"#{@soundcloudfolder}#{name}.mp3\"") if !File.exist?("#{@soundcloudfolder}#{name}.mp3")
                            @songlist << name.split("/")[-1] + ".mp3"
                        end
                    end
                end
            end
        end
    end
    
end
