class Ektoplazm < Plugin

  def init(init)
    super
    if ( @@bot[:mpd] ) && ( @@bot[:messages] ) && ( @@bot[:ektoplazm].nil? )
      logger("INFO: INIT plugin #{self.class.name}.")
      begin
        @ektoplazmfolder = Conf.gvalue("plugin:mpd:musicfolder") + Conf.gvalue("plugin:ektoplazm:folder:download")
        @tempektoplazmfolder = Conf.gvalue("main:tempdir") + Conf.gvalue("plugin:ektoplazm:folder:temp")
        Dir.mkdir(@ektoplazmfolder) unless File.exists?(@ektoplazmfolder)
        Dir.mkdir(@tempektoplazmfolder) unless File.exists?(@tempektoplazmfolder)
      rescue
        logger "ERROR: Ektoplazm-Plugin doesn't found settings for mpd music directory and/or your preferred temporary download directory"
        logger "See config/config.yml"
      end
      @consoleaddition = ""
      @consoleaddition = Conf.gvalue("plugin:ektoplazm:prefixes") if Conf.gvalue("plugin:ektoplazm:prefixes")
      @songlist = Queue.new
      @keylist = Array.new
      @@bot[:ektoplazm] = self
    end
    return @@bot
  end

  def name
    if ( @@bot[:mpd].nil? ) || ( @@bot[:ektoplazm].nil?)
      "false"
    else
      self.class.name
    end
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{Conf.gvalue("main:control:string")}ektoplazm <i>URL</i></b> - #{I18n.t("plugin_ektoplazm.help.ektoplazm")}<br />"
    h << "<br />#{I18n.t("plugin_ektoplazm.help.information")}"
  end

  def handle_chat(msg, message)
    super
    if message.start_with?("ektoplazm <a href=") || message.start_with?("<a href=") then
      link = msg.message[msg.message.index('>') + 1 .. -1]
      link = link[0..link.index('<')-1]
      workingdownload = Thread.new {
        #local variables for this thread!
        actor = msg.actor
        Thread.current["user"]=msg.username
        Thread.current["process"]="ektoplatzm"

        if ( link.include? "www.ektoplazm.com/files" ) then
          if !File.writable?(@temp) || !File.writable?(@destination)
            logger "I do not have write permissions in \"#{@temp}\" or in \"#{@destination}\"."
            #error << "I do not have write permissions in temp or in music directory. Please contact an admin."
            #return error
          end

          messageto(actor, I18n.t("plugin_ektoplazm.inspecting", :link => link))
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
            @@bot[:mpd].update(Conf.gvalue("plugin:ektoplazm:folder:download").gsub(/\//,""))
            messageto(actor, I18n.t("plugin_ektoplazm.db_update"))

            begin
              #Caution! following command needs patched ruby-mpd!
              @@bot[:mpd].idle("update")
              # find this lines in ruby-mpd/plugins/information.rb (actual 47-49)
              # def idle(*masks)
              #  send_command(:idle, *masks)
              # end
              # and uncomment it there, then build gem new.
            rescue
              logger "[INFO] idle-patch of ruby-mpd not implemented. Sleeping 10 seconds."
              sleep 10
            end

            messageto(actor, I18n.t("plugin_ektoplazm.db_update_done"))
            while @songlist.size > 0
              song = @songlist.pop
              messageto(actor, song)
              @@bot[:mpd].add(Conf.gvalue("plugin:ektoplazm:folder:download")+song)
            end
          else
            messageto(actor, I18n.t("plugin_ektoplazm.badlink"))
          end
        else
          messageto(actor, I18n.t("plugin_ektoplazm.no_ektoplazm")) if message.start_with?("ektoplazm")
        end
      }
    end
  end

end
