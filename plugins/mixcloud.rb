require_relative '../helpers/YTDL.rb'

class Mixcloud < Plugin

  def init(init)
    super

    if ( !@@bot[:mpd].nil? ) && ( @@bot[:messages] ) && ( @@bot[:mixcloud].nil? )
      logger("INFO: INIT plugin #{self.class.name}.")
      @loader = YTDL.new
      begin
        dest = Conf.gvalue("plugin:mpd:musicfolder") + Conf.gvalue("plugin:mixcloud:folder:download")
        temp = Conf.gvalue("main:tempdir") + Conf.gvalue("plugin:mixcloud:folder:temp")
        Dir.mkdir(dest) unless File.exists?(dest)
        Dir.mkdir(temp) unless File.exists?(temp)
        @loader.dest(dest)
        @loader.temp(temp)
      rescue
        logger "ERROR: Mixcloud-Plugin didn't found settings for mpd music directory and/or your preferred temporary download directory"
        logger "See config/config.yml"
      end
      @writeable = true
      if !File.writable?(temp) || !File.writable?(dest)
        logger "WARNING: Mixcloud-Plugin has no write permissions in \"#{temp}\" or in \"#{dest}\"."
        @writeable = false
      end
      @loader.options(Conf.gvalue("plugin:mixcloud:youtube_dl:options"))
      @loader.prefix(@consoleaddition = Conf.gvalue("plugin:mixcloud:youtube_dl:prefixes"))
      @loader.executeable(Conf.gvalue("plugin:mixcloud:youtube_dl:path"))
      @@bot[:mixcloud] = self
    end
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
      privatemessage(I18n.t("plugin_mixcloud.ytdlversion", :version => @loader.version))
    end

    if (message.start_with?("mixcloud <a href=") || message.start_with?("<a href=")) && @writeable then
      link = msg.message.match(/http[s]?:\/\/(.+?)\"/).to_s.chop
      if link.include? "mixcloud" then
        Thread.new do
          #local variables for this thread!
          actor = msg.actor
          Thread.current["user"]=msg.username
          Thread.current["process"]="mixcloud"

          messageto(actor, I18n.t("plugin_mixcloud.inspecting", :link => link))
          @loader.get_files(link)
          if ( @loader.size > 0 ) then
            @@bot[:mpd].update(Conf.gvalue("plugin:mixcloud:folder:download").gsub(/\//,""))
            messageto(actor, I18n.t("plugin_mixcloud.db_update"))
            while @@bot[:mpd].status[:updating_db] do
              sleep 0.5
            end
            messageto(actor, I18n.t("plugin_mixcloud.db_update_done"))
            songs =""
            while @loader.size > 0
              song = @songlist.get_song
              songs << "<br> #{song[:name]}"
              @@bot[:mpd].add(Conf.value("plugin:mixcloud:folder:download")+song[:name]+song[:extention])
            end
            messageto(actor, songs)
          else
            messageto(actor, I18n.t("plugin_mixcloud.badlink"))
          end
        end
      end
    end
  end
end
