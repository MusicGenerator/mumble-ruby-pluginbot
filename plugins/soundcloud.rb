class Soundcloud < Plugin

  def init(init)
    super
    if ( @@bot[:mpd] ) && ( @@bot[:messages] ) && ( @@bot[:soundcloud].nil? )
      logger("INFO: INIT plugin #{self.class.name}.")
      begin
        @destination = Conf.gvalue("plugin:mpd:musicfolder") + Conf.gvalue("plugin:soundcloud:folder:download")
        @temp = Conf.gvalue("main:tempdir") + Conf.gvalue("plugin:soundcloud:folder:temp")

        Dir.mkdir(@destination) unless File.exists?(@destination)
        Dir.mkdir(@temp) unless File.exists?(@temp)
      rescue
        logger "ERROR: soundcloud-Plugin doesn't found settings for mpd music directory and/or your preferred temporary download directory"
        logger "See pluginbot_conf.yaml"
      end
      begin
        @ytdloptions = Conf.gvalue("plugin:soundcloud:youtube_dl:options")
      rescue
        @ytdloptions = ""
      end
      @consoleaddition = ""
      @consoleaddition = Conf.gvalue("plugin:soundcloud:prefixes") if Conf.gvalue("plugin:soundcloud:prefixes")
      @executable = "#"
      @executable = Conf.gvalue("plugin:soundcloud:youtube_dl:path") if Conf.gvalue("plugin:soundcloud:youtube_dl:path")
      @songlist = Queue.new
      @keylist = Array.new
      @@bot[:soundcloud] = self
    end
    @filetypes= ["ogg", "mp3", "mp2", "m4a", "aac", "wav", "ape", "flac"]
    return @@bot
  end

  def name
    if ( @@bot[:mpd].nil? ) || ( @@bot[:soundcloud].nil?)
      "false"
    else
      self.class.name
    end
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{Conf.gvalue("main:control:string")}soundcloud <i>URL</i></b> - #{I18n.t("plugin_soundcloud.help.soundcloud")} <br>"
    h << "<b>#{Conf.gvalue("main:control:string")}ytdl-version</b> - #{I18n.t("plugin_soundcloud.help.ytdl_version")}"
  end

  def handle_chat(msg, message)
    super

    if message == "ytdl-version"
      privatemessage(I18n.t("plugin_soundcloud.ytdlversion" , :version => `#{@executable} --version`) )
    end

    if message.start_with?("soundcloud <a href=") || message.start_with?("<a href=") then
      link = msg.message.match(/http[s]?:\/\/soundcloud(.+?)\"/).to_s.chop
      if link != "" then
        Thread.new do
          #local variables for this thread!
          actor = msg.actor
          Thread.current["user"]=actor
          Thread.current["process"]="soundcloud"
          messageto(actor, I18n.t("plugin_soundcloud.inspecting", :link => link ))
          get_song link
          if ( @songlist.size > 0 ) then
            @@bot[:mpd].update(Conf.gvalue("plugin:soundcloud:folder:download").gsub(/\//,""))
            messageto(actor, I18n.t("plugin_soundcloud.db_update"))

            while @@bot[:mpd].status[:updating_db] do
              sleep 0.5
            end

            messageto(actor, I18n.t("plugin_soundcloud.db_update_done"))
            while @songlist.size > 0
              song = @songlist.pop
              messageto(actor, song)
              @@bot[:mpd].add(Conf.gvalue("plugin:soundcloud:folder:download")+song)
            end
          else
            messageto(actor, I18n.t("plugin_soundcloud.badlink"))
          end
        end
      end
    end
  end

  def get_song(site)
    error = Array.new
    if ( site.include? "soundcloud.com/" ) then
      if !File.writable?(@temp) || !File.writable?(@destination)
        logger "I do not have write permissions in \"#{@temp}\" or in \"#{@destination}\"."
        error << "I do not have write permissions in temp or in music directory. Please contact an admin."
        return error
      end

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

            if Conf.gvalue("plugin:soundcloud:to_mp3").nil?
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
