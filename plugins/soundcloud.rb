class Soundcloud < Plugin

  def init(init)
    super
    if ( @@bot[:mpd] != nil ) && ( @@bot[:messages] != nil ) && ( @@bot[:soundcloud] == nil )
      begin
        @destination = @@bot["plugin"]["mpd"]["musicfolder"] + @@bot["plugin"]["soundcloud"]["folder"]["download"]
        @temp = @@bot["main"]["tempdir"] + @@bot["plugin"]["soundcloud"]["folder"]["temp"]

        Dir.mkdir(@destination) unless File.exists?(@destination)
        Dir.mkdir(@temp) unless File.exists?(@temp)
      rescue
        puts "Error: soundcloud-Plugin doesn't found settings for mpd music directory and/or your preferred temporary download directory"
        puts "See pluginbot_conf.yaml"
      end
      begin
        @ytdloptions = @@bot["plugin"]["soundcloud"]["youtube_dl"]["options"]
      rescue
        @ytdloptions = "" 
      end
      @consoleaddition = "" 
      @consoleaddition = @@bot["plugin"]["soundcloud"]["prefixes"] if @@bot["plugin"]["soundcloud"]["prefixes"] != nil
      @executable = "#"
      @executable = @@bot["plugin"]["soundcloud"]["youtube_dl"]["path"] if @@bot["plugin"]["soundcloud"]["youtube_dl"]["path"] != nil
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
    h << "<b>#{@@bot["main"]["control"]["string"]}soundcloud <i>URL</i></b> - Will try to download the music from the given URL. <br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}ytdl-version</b> - print used download helper version"
  end

  def handle_chat(msg, message)
    super

    if message == "ytdl-version"
      privatemessage("Soundcloud uses youtube-dl " + `#{@executable} --version`) 
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
            @@bot[:mpd].update(@@bot["plugin"]["soundcloud"]["folder"]["download"].gsub(/\//,"")) 
            messageto(actor, "Waiting for database update complete...")

            while @@bot[:mpd].status[:updating_db] != nil do
              sleep 0.5
            end

            messageto(actor, "Update done.")
            while @songlist.size > 0 
              song = @songlist.pop
              messageto(actor, song)
              @@bot[:mpd].add(@@bot["plugin"]["soundcloud"]["folder"]["download"]+song)
            end
          else
            messageto(actor, "Soundcloud: The link contains nothing interesting.") 
          end
        end
      end
    end
  end

  def get_song(site)
    error = Array.new
    if ( site.include? "soundcloud.com/" ) then
      site.gsub!(/<\/?[^>]*>/, '')
      site.gsub!("&amp;", "&")
      filename = `#{@executable} --get-filename #{@ytdloptions} -i -o \"#{@temp}%(title)s\" "#{site}"`
      output =`#{@consoleaddition} #{@executable} #{@ytdloptions} --write-thumbnail -x --audio-format best -o \"#{@temp}%(title)s.%(ext)s\" \"#{site}\" `     #get icon
      output.each_line do |line|
        error << line if line.include? "ERROR:"
      end
      filename.split("\n").each do |name|
        name.slice! @temp #This is probably a bad hack but name is here for example "/home/botmaster/temp/youtubeplugin//home/botmaster/temp/youtubeplugin/filename.mp3"
        @filetypes.each do |ending|
          if File.exist?("#{@temp}#{name}.#{ending}")
            system ("#{@consoleaddition} convert \"#{@temp}#{name}.jpg\" -resize 320x240 \"#{@destination}#{name}.jpg\" ")

            if @@bot["plugin"]["soundcloud"]["to_mp3"] == nil
              # Mixin tags without recode on standard
              system ("#{@consoleaddition} ffmpeg -i \"#{@temp}#{name}.#{ending}\" -acodec copy -metadata title=\"#{name}\" \"#{@destination}#{name}.#{ending}\"") if !File.exist?("#{@destination}#{name}.#{ending}")
              @songlist << name.split("/")[-1] + ".#{ending}"
            else
              # Mixin tags and recode it to mp3 (vbr 190kBit)
              system ("#{@consoleaddition} ffmpeg -i \"#{@temp}#{name}.#{ending}\" -codec:a libmp3lame -qscale:a 2 -metadata title=\"#{name}\" \"#{@destination}#{name}.mp3\"") if !File.exist?("#{@destination}#{name}.mp3")
              @songlist << name.split("/")[-1] + ".mp3"
            end
          end
        end
      end
    end
  end

end
