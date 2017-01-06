require_relative '../helpers/YTDL.rb'

class Bandcamp < Plugin

  def init(init)
    super

    if ( !@@bot[:mpd].nil? ) && ( @@bot[:messages] ) && ( @@bot[:bandcamp].nil? )
      logger("INFO: INIT plugin #{self.class.name}.")
      @loader = YTDL.new
      begin
        dest = Conf.gvalue("plugin:mpd:musicfolder") + Conf.gvalue("plugin:bandcamp:folder:download")
        temp = Conf.gvalue("main:tempdir") + Conf.gvalue("plugin:bandcamp:folder:temp")
        Dir.mkdir(dest) unless File.exists?(dest)
        Dir.mkdir(temp) unless File.exists?(temp)
        @loader.dest(dest)
        @loader.temp(temp)
      rescue
        logger "Error: bandcamp-Plugin didn't found settings for mpd music directory and/or your preferred temporary download directory"
        logger "See config/config.yml"
      end
      @writeable = true
      if !File.writable?(temp) || !File.writable?(dest)
        logger "WARNING: Bandcamp-Plugin has no write permissions in \"#{temp}\" or in \"#{dest}\"."
        @writeable = false
      end

      @loader.options(Conf.gvalue("plugin:bandcamp:youtube_dl:options"))
      @loader.prefix(Conf.gvalue("plugin:bandcamp:youtube_dl:prefixes"))
      @loader.executeable(Conf.gvalue("plugin:bandcamp:youtube_dl:path"))
      @keylist = Array.new
      @@bot[:bandcamp] = self
    end
    return @@bot
  end

  def name
      if ( @@bot[:mpd].nil? ) || ( @@bot[:bandcamp].nil?)
          "false"
      else
          self.class.name
      end
  end

  def help(h)
      h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
      h << "<b>#{Conf.gvalue("main:control:string")}bandcamp <i>URL</i></b> - #{I18n.t("plugin_bandcamp.help.bandcamp")}<br>"
      h << "<b>#{Conf.gvalue("main:control:string")}ytdl-version</b> - #{I18n.t("plugin_bandcamp.help.ytdl_version")}"
  end

  def handle_chat(msg, message)
    super

    if message == "ytdl-version"
      privatemessage("#{I18n.t("plugin_bandcamp.ytdlversion", :version => @loader.version)}")
    end

    if (message.start_with?("bandcamp <a href=") || message.start_with?("<a href=")) && @writeable then
      link = msg.message.match(/http[s]?:\/\/(.+?)\"/).to_s.chop
      if link.include? "bandcamp" then
        Thread.new do
          #local variables for this thread!
          actor = msg.actor
          Thread.current["user"]=msg.username
          Thread.current["process"]="bandcamp"

          messageto(actor, I18n.t("plugin_bandcamp.inspecting", :link => link ))
          @loader.get_files(link)
          if ( @loader.size > 0 ) then
            @@bot[:mpd].update(Conf.gvalue("plugin:bandcamp:folder:download").gsub(/\//,""))
            messageto(actor, I18n.t("plugin_bandcamp.db_update"))
            while @@bot[:mpd].status[:updating_db] do
              sleep 0.5
            end
            messageto(actor, I18n.t("plugin_bandcamp.db_update_done"))
            songs = ""
            while @loader.size > 0
              title = @loader.get_song
              songs << "<br> #{title[:name]}"
              @@bot[:mpd].add(Conf.gvalue("plugin:bandcamp:folder:download")+title[:name]+title[:extention])
            end
            messageto(actor, songs)
          else
            messageto(actor, I18n.t("plugin_bandcamp.badlink"))
          end
        end
      end
    end
  end
end
