class Mixcloud < Plugin

  def init(init)
    super

    if ( !@@bot[:mpd].nil? ) && ( @@bot[:messages] ) && ( @@bot[:mixcloud].nil? )
      logger("INFO: INIT plugin #{self.class.name}.")
      begin
        @destination = Conf.gvalue("plugin:mpd:musicfolder") + Conf.gvalue("plugin:mixcloud:folder:download")
        @temp = Conf.gvalue("main:tempdir") + Conf.gvalue("plugin:mixcloud:folder:temp")
        Dir.mkdir(@destination) unless File.exists?(@destination)
        Dir.mkdir(@temp) unless File.exists?(@temp)
      rescue
        logger "ERROR: Mixcloud-Plugin didn't found settings for mpd music directory and/or your preferred temporary download directory"
        logger "See config/config.yml"
      end
      @ytdloptions = ""
      @consoleaddition = ""
      begin
        @ytdloptions = Conf.gvalue("plugin:mixcloud:youtube_dl:options")
        @consoleaddition = Conf.gvalue("plugin:mixcloud:youtube_dl:prefixes")
      rescue
      end
      @songlist = Queue.new
      @keylist = Array.new
      @@bot[:mixcloud] = self
    end
    @filetypes= ["ogg", "mp3", "mp2", "m4a", "aac", "wav", "ape", "flac"]
    return @@bot
  end

  def name
      if ( @@bot[:mpd].nil? ) || ( @@bot[:mixcloud].nil?)
          "false"
      else
          self.class.name
      end
  end

  def help(h)
      h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
      h << "<b>#{Conf.gvalue("main:control:string")}mixcloud <i>URL</i></b> - #{I18n.t("plugin_mixcloud.help.mixcloud")}<br>"
      h << "<b>#{Conf.gvalue("main:control:string")}ytdl-version</b> - #{I18n.t("plugin_mixcloud.help.ytdl_version")}"
  end

  def handle_chat(msg, message)
    super

    if message == "ytdl-version"
      privatemessage(I18n.t("plugin_mixcloud.ytdlversion", :version => `#{Conf.gvalue("plugin:mixcloud:youtube_dl:path")} --version`))
    end

    if message.start_with?("mixcloud <a href=") || message.start_with?("<a href=") then
      link = msg.message.match(/http[s]?:\/\/(.+?)\"/).to_s.chop
      if link.include? "mixcloud" then
        Thread.new do
          #local variables for this thread!
          actor = msg.actor
          Thread.current["user"]=actor
          Thread.current["process"]="mixcloud"

          messageto(actor, I18n.t("plugin_mixcloud.inspecting", :link => link))
          get_song link
          if ( @songlist.size > 0 ) then
            @@bot[:mpd].update(Conf.gvalue("plugin:mixcloud:folder:download").gsub(/\//,""))
            messageto(actor, I18n.t("plugin_mixcloud.db_update"))

            while @@bot[:mpd].status[:updating_db] do
              sleep 0.5
            end

            messageto(actor, I18n.t("plugin_mixcloud.db_update_done"))
            while @songlist.size > 0
              song = @songlist.pop
              messageto(actor, song)
              @@bot[:mpd].add(Conf.value("plugin:mixcloud:folder:download")+song)
            end
          else
            messageto(actor, I18n.t("plugin_mixcloud.badlink"))
          end
        end
      end
    end
  end

  def get_song(site)
    if ( site.include? "mixcloud.com/" ) then
      if !File.writable?(@temp) || !File.writable?(@destination)
        logger "I do not have write permissions in \"#{@temp}\" or in \"#{@destination}\"."
        #error << "I do not have write permissions in temp or in music directory. Please contact an admin."
        return
      end

      site.gsub!(/<\/?[^>]*>/, '')
      site.gsub!("&amp;", "&")

      is_album = false

      if site.match(/album\/(.*)/)
        is_album = true
        albumname = site.match(/album\/(.*)/)[1]
        albumname.gsub!(" ", "_")

        finaldirectory = "#{@destination}/#{albumname}"
        Dir.mkdir(finaldirectory) unless File.exists?(finaldirectory)
      else #no album
        albumname = ""
        finaldirectory = "#{@destination}"
      end

      logger site

      filename = `#{Conf.gvalue("plugin:mixcloud:youtube_dl:path")} --get-filename #{@ytdloptions} -i -o \"#{@temp}%(title)s\" "#{site}"`
      output =`nice -n20 #{@consoleaddition} #{Conf.gvalue("plugin:mixcloud:youtube_dl:path")} #{@ytdloptions} --write-thumbnail -x --audio-format best -o \"#{@temp}%(title)s.%(ext)s\" \"#{site}\" `     #get icon
      filename.split("\n").each do |name|
        name.slice! @temp #This is probably a bad hack but name is here for example "/home/botmaster/temp/youtubeplugin//home/botmaster/temp/youtubeplugin/filename.mp3"
        @filetypes.each do |ending|
          if File.exist?("#{@temp}#{name}.#{ending}")
            system ("nice -n20 #{@consoleaddition} convert \"#{@temp}#{name}.jpg\" -resize 320x240 \"#{@destination}#{name}.jpg\" ")
            # Mixin tags without recode on standard

            system ("nice -n20 #{@consoleaddition} cp \"#{@temp}#{name}.#{ending}\" \"#{finaldirectory}/#{name}.#{ending}\"") if !File.exist?("#{finaldirectory}/#{name}.#{ending}")

            if is_album
              @songlist << albumname + "/" + name.split("/")[-1] + ".#{ending}"
            else
              @songlist << name.split("/")[-1] + ".#{ending}"
            end
          end
        end
      end
    end
  end
end
