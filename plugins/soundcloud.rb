class Soundcloud < Plugin

  def init(init)
    super
    if ( @@bot[:mpd] != nil ) && ( @@bot[:messages] != nil ) && ( @@bot[:soundcloud] == nil )
      begin
        @soundcloudfolder = @@bot[:mpd_musicfolder] + @@bot[:soundcloud_downloadsubdir]
        @tempsoundcloudfolder = @@bot[:main_tempdir] + @@bot[:soundcloud_tempsubdir]
        
        Dir.mkdir(@soundcloudfolder) unless File.exists?(@soundcloudfolder)
        Dir.mkdir(@tempsoundcloudfolder) unless File.exists?(@tempsoundcloudfolder)
      rescue
        puts "Error: soundcloud-Plugin doesn't found settings for mpd music directory and/or your preferred temporary download directory"
        puts "See pluginbot_conf.rb"
      end
      begin
        @ytdloptions = @@bot[:soundcloud_youtubedl_options]
      rescue
        @ytdloptions = "" 
      end
      @consoleaddition = "" 
      @consoleaddition = @@bot[:soundcloud_commandlineprefixes] if @@bot[:soundcloud_commandlineprefixes] != nil
      @songlist = Queue.new
      @keylist = Array.new
      @@bot[:soundcloud] = self
    end
    @filetypes= ["ogg", "mp3", "mp2", "m4a", "aac", "wav", "ape", "flac"]
    return @@bot
  end

  def name
    if ( @@bot[:mpd] == nil ) || ( @@bot[:soundcloud] == nil)
      "false"
    else    
      self.class.name
    end
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{@@bot[:controlstring]}soundcloud <i>URL</i></b> - Will try to download the music from the given URL. <br>"
    h << "<b>#{@@bot[:controlstring]}ytdl-version</b> - print used download helper version"
  end

  def handle_chat(msg, message)
    super

    if message == "ytdl-version"
      privatemessage("Soundcloud uses youtube-dl " + `#{@@bot[:soundcloud_youtubedl]} --version`) 
    end

    if message.start_with?("soundcloud <a href=") || message.start_with?("<a href=") then
      link = msg.message.match(/http[s]?:\/\/soundcloud(.+?)\"/).to_s.chop
      if link != "" then
        Thread.new do
          #local variables for this thread!
          actor = msg.actor
          Thread.current["user"]=actor
          Thread.current["process"]="soundcloud"
          messageto(actor, "Soundcloud is inspecting link: " + link + "...")
          get_song link
          if ( @songlist.size > 0 ) then
            @@bot[:mpd].update(@@bot[:soundcloud_downloadsubdir].gsub(/\//,"")) 
            messageto(actor, "Waiting for database update complete...")
            
            while @@bot[:mpd].status[:updating_db] != nil do
              sleep 0.5
            end          
            
            messageto(actor, "Update done.")
            while @songlist.size > 0 
              song = @songlist.pop
              messageto(actor, song)
              @@bot[:mpd].add(@@bot[:soundcloud_downloadsubdir]+song)
            end
          else
            messageto(actor, "Soundcloud: The link contains nothing interesting.") if @@bot[:soundcloud_stream] == nil
          end
        end
      end
    end
  end

  def get_song(site)
    if ( site.include? "soundcloud.com/" ) then
      site.gsub!(/<\/?[^>]*>/, '')
      site.gsub!("&amp;", "&")
      puts site
      filename = `#{@@bot[:soundcloud_youtubedl]} --get-filename #{@ytdloptions} -i -o \"#{@tempdownloadfoler}%(title)s\" "#{site}"`
      output =`nice -n20 #{@consoleaddition} #{@@bot[:soundcloud_youtubedl]} #{@ytdloptions} --write-thumbnail -x --audio-format best -o \"#{@tempsoundcloudfolder}%(title)s.%(ext)s\" \"#{site}\" `     #get icon
      filename.split("\n").each do |name|
        @filetypes.each do |ending|
          if File.exist?("#{@tempsoundcloudfolder}#{name}.#{ending}")
            system ("nice -n20 #{@consoleaddition} convert \"#{@tempsoundcloudfolder}#{name}.jpg\" -resize 320x240 \"#{@soundcloudfolder}#{name}.jpg\" ")
            if @@bot[:soundcloud_to_mp3] == nil
              # Mixin tags without recode on standard
              system ("nice -n20 #{@consoleaddition} ffmpeg -i \"#{@tempsoundcloudfolder}#{name}.#{ending}\" -acodec copy -metadata title=\"#{name}\" \"#{@soundcloudfolder}#{name}.#{ending}\"") if !File.exist?("#{@soundcloudfolder}#{name}.#{ending}")
              @songlist << name.split("/")[-1] + ".#{ending}"
            else
              # Mixin tags and recode it to mp3 (vbr 190kBit)
              system ("nice -n20 #{@consoleaddition} ffmpeg -i \"#{@tempsoundcloudfolder}#{name}.#{ending}\" -codec:a libmp3lame -qscale:a 2 -metadata title=\"#{name}\" \"#{@soundcloudfolder}#{name}.mp3\"") if !File.exist?("#{@soundcloudfolder}#{name}.mp3")
              @songlist << name.split("/")[-1] + ".mp3"
            end
          end
        end
      end
    end
  end
  
end
