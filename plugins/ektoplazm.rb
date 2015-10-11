class Ektoplazm < Plugin

    def init(init)
        super
        if ( @@bot[:mpd] != nil ) && ( @@bot[:messages] != nil ) && ( @@bot[:ektoplazm] == nil )
            begin
                @ektoplazmfolder = @@bot[:mpd_musicfolder] + @@bot[:ektoplazm_downloadsubdir]
                @tempektoplazmfolder = @@bot[:main_tempdir] + @@bot[:ektoplazm_tempsubdir]
                
                Dir.mkdir(@ektoplazmfolder) unless File.exists?(@ektoplazmfolder)
                Dir.mkdir(@tempektoplazmfolder) unless File.exists?(@tempektoplazmfolder)
            rescue
                puts "Error: Ektoplazm-Plugin doesn't found settings for mpd music directory and/or your preferred temporary download directory"
                puts "See pluginbot_conf.rb"
            end
            @consoleaddition = "" 
            @consoleaddition = @@bot[:ektoplazm_commandlineprefixes] if @@bot[:ektoplazm_commandlineprefixes] != nil
            @songlist = Queue.new
            @keylist = Array.new
            @@bot[:ektoplazm] = self
        end
        return @@bot
    end

    def name
        if ( @@bot[:mpd] == nil ) || ( @@bot[:ektoplazm] == nil)
            "false"
        else    
            self.class.name
        end
    end

    def help(h)
        h += "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br />"
        h += "<b>#{@@bot[:controlstring]}ektoplazm <i>URL</i></b> - Will try to download the music from the given URL."
    end

    def handle_chat(msg, message)
        super
        if message.start_with?("ektoplazm <a href=") || message.start_with?("<a href=") then
            link = msg.message[msg.message.index('>') + 1 .. -1]
            link = link[0..link.index('<')-1]
            workingdownload = Thread.new {
                #local variables for this thread!
                actor = msg.actor
                if ( link.include? "www.ektoplazm.com/files" ) then
                    @@bot[:messages].text(actor, "ektoplazm is inspecting link: " + link + "...")
                    link.gsub!(/<\/?[^>]*>/, '')
                    link.gsub!("&amp;", "&")
                    name = link.split("/")[-1]
                    if !name.include? ".rar"                       
                        # only zip archives! (mp3 and flac)
                        if !File.exist?("#{@tempektoplazmfolder}#{name}")
                            system ("curl -o \"#{@tempektoplazmfolder}#{name}\" #{link}")
                        end
                        if File.exist?("#{@tempektoplazmfolder}#{name}")
                            system ("unzip -o \"#{@tempektoplazmfolder}#{name}\" -d \"#{@tempektoplazmfolder}\"")
                            Dir.chdir(@tempektoplazmfolder)
                            files = Dir.glob("*.mp3")
                            files += Dir.glob ("*.flac")
                            files.each do |file|
                                if File.file?(@tempektoplazmfolder + file)
                                    File.rename(@tempektoplazmfolder + file, @ektoplazmfolder + file)
                                    @songlist << file
                                end
                            end
                        end
                    end
                    if ( @songlist.size > 0 ) then
                        @@bot[:mpd].update(@@bot[:ektoplazm_downloadsubdir].gsub(/\//,"")) 
                        @@bot[:messages].text(actor, "Waiting for database update complete...")
                        
                        begin
                            #Caution! following command needs patched ruby-mpd!
                            @@bot[:mpd].idle("update")
                            # find this lines in ruby-mpd/plugins/information.rb (actual 47-49)
                            # def idle(*masks)
                            #  send_command(:idle, *masks)
                            # end
                            # and uncomment it there, then build gem new.
                        rescue
                            puts "[Ektoplazm-plugin] [info] idle-patch of ruby-mpd not implemented. Sleeping 10 seconds." if @@bot[:debug]
                            sleep 10
                        end
                            
                        @@bot[:messages].text(actor, "Update done.")
                        while @songlist.size > 0 
                            song = @songlist.pop
                            @@bot[:messages].text(actor, song)
                            @@bot[:mpd].add(@@bot[:ektoplazm_downloadsubdir]+song)
                        end
                    else
                        @@bot[:messages].text(actor, "Ektoplazm: The link contains nothing interesting.") if @@bot[:Ektoplazm_stream] == nil
                    end
                else
                    @@bot[:messages].text(actor, "No ektoplazm link!?") if message.start_with?("ektoplazm")
                end
            }
        end
    end
    
end
