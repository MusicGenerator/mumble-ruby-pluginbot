require 'cgi'
require_relative '../helpers/YTDL.rb'

class Youtube < Plugin

  def init(init)
    super
    if ( @@bot[:mpd] ) && ( @@bot[:messages] ) && ( @@bot[:youtube].nil? )
      logger("INFO: INIT plugin #{self.class.name}.")
      @loader = YTDL.new
      begin
        dest = Conf.gvalue("plugin:mpd:musicfolder") + Conf.gvalue("plugin:youtube:folder:download")
        temp = Conf.gvalue("main:tempdir") + Conf.gvalue("plugin:youtube:folder:temp")
        @loader.dest dest
        @loader.temp temp

        Dir.mkdir(dest) unless File.exists?(dest)
        Dir.mkdir(temp) unless File.exists?(temp)
      rescue
        logger "Error: Youtube-Plugin didn't find settings for mpd music directory and/or your preferred temporary download directory."
        logger "See ../config/config.yml"
      end
      @loader.options Conf.gvalue("plugin:youtube:options")
      @loader.prefix  Conf.gvalue("plugin:youtube:youtube_dl:prefixes") if Conf.gvalue("plugin:youtube:youtube_dl:prefixes")
      @loader.executeable Conf.gvalue("plugin:youtube:youtube_dl:path") if Conf.gvalue("plugin:youtube:youtube_dl:path")

      @@bot[:youtube] = self
    end
    @keylist = Array.new
    return @@bot
  end

  def name
    if ( @@bot[:mpd].nil? ) || ( @@bot[:youtube].nil?)
      "false"
    else
      self.class.name
    end
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{Conf.gvalue("main:control:string")}ytlink <i>URL</i></b> - #{I18n.t('plugin_youtube.help.ytlink')}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}yts keywords</b> - #{I18n.t('plugin_youtube.help.yts')}<br>"
#   ytstream does not correct operate at the moment.
#    h << "<b>#{Conf.gvalue("main:control:string")}ytstream <i>URL</i></b> - #{I18n.t('plugin_youtube.help.ytstream')}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}yta <i>number</i> <i>number2</i> <i>number3</i></b> - #{I18n.t('plugin_youtube.help.yta', :controlstring => Conf.gvalue("main:control:string"))}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}ytdl-version</b> - #{I18n.t('plugin_youtube.help.ytdl_version')}"
  end

  def handle_chat(msg, message)
    super

    if message == "ytdl-version"
      privatemessage(I18n.t('plugin_youtube.ytdlversion', :version => @loader.version))
    end

    if message.start_with?("ytlink <a href=") || message.start_with?("<a href=") then
      link = msg.message.match(/http[s]?:\/\/(.+?)\"/).to_s.chop
      if ( link.include? "www.youtube.com/" ) || ( link.include? "youtu.be/" ) || ( link.include? "m.youtube.com/" ) then
        Thread.new do
          #local variables for this thread!
          actor = msg.actor
          name = msg.username
          logger "INFO: Youtube start Thread for #{name}."
          Thread.current["user"]=name
          Thread.current["process"]="youtube (download)"

          messageto(actor, I18n.t('plugin_youtube.inspecting', :link => link ))

          @loader.get_files(link)

          if @loader.size > 0 then
            @@bot[:mpd].update(Conf.gvalue("plugin:youtube:folder:download").gsub(/\//,""))
            messageto(actor, I18n.t('plugin_youtube.db_update'))
            while @@bot[:mpd].status[:updating_db] do
              sleep 0.5
            end
            messageto(actor, I18n.t('plugin_youtube.db_update_done'))
            songs = ""
            while @loader.size > 0
              title = @loader.get_song
              songs << "<br> #{title[:name]}"
              @@bot[:mpd].add(Conf.gvalue("plugin:youtube:folder:download")+title[:name]+title[:extention])
            end
            messageto(actor, songs)
          else
            messageto(actor, I18n.t('plugin_youtube.badlink'))
          end
          logger "INFO: Youtube end Thread for #{name}."
        end
      end
    end

    if message.split[0] == 'yts'
      search = message[4..-1]
      if !(( search.nil? ) || ( search == "" ))
        Thread.new do
          Thread.current["user"]=msg.username
          Thread.current["process"]="youtube (yts)"

          messageto(msg.actor, I18n.t('plugin_youtube.yts.search', :search => search ))
          songs = find_youtube_song(CGI.escape(search))
          @keylist[msg.actor] = songs
          index = 0
          out = ""
          @keylist[msg.actor].each do |id , title|
            if ( ( index % 30 ) == 0 )
              messageto(msg.actor, out + "</table>") if index != 0
              out = "<table><tr><td><b>Index</b></td><td>Title</td></tr>"
            end
            out << "<tr><td><b>#{index}</b></td><td>#{title}</td></tr>"
            index += 1
          end
          out << "</table>"
          messageto(msg.actor, out)
        end
      else
        messageto(msg.actor, I18n.t('plugin_youtube.yts.nofound'))
      end
    end

#    This Code is out of function at the moment.
#
#    if message.split[0] == 'ytstream'
#      link = msg.message.match(/http[s]?:\/\/(.+?)\"/).to_s.chop
#      link.gsub!(/<\/?[^>]*>/, '')
#      link.gsub!("&amp;", "&")
#
#      messageto(msg.actor, I18n.t('plugin_youtube.inspecting', :link => link ))
#
#      streams = `#{@executable} -g "#{link}"`
#      streams.each_line do |line|
#        line.chop!
#        @@bot[:mpd].add line if line.include? "mime=audio/mp4"
#        messageto(msg.actor, I18n.t("plugin_youtube.ytstream.added", :link => link))
#      end
#
#    end

    if message.split[0] == 'yta'
      begin
        out = "<br>#{I18n.t('plugin_youtube.yta.download')}<br>"
        msg_parameters = message.split[1..-1].join(" ")
        link = []

        if msg_parameters.match(/(?:[\d{1,3}\ ?])+/) # User gave us at least one id or multiple ids to download.
          id_list = msg_parameters.match(/(?:[\d{1,3}\ ?])+/)[0].split
          id_list.each do |id|
            downloadid = @keylist[msg.actor][id.to_i]
            out << "#{I18n.t('plugin_youtube.yta.id', :id => id, :name => downloadid[0])}<br>"
            link << "https://www.youtube.com/watch?v="+downloadid[0]
          end
          messageto(msg.actor, out)
        end

        if msg_parameters == "all"
          @keylist[msg.actor].each do |downloadid|
            out << "#{I18n.t('plugin_youtube.yta.all',:name => downloadid[0])}<br>"
            link << "https://www.youtube.com/watch?v="+downloadid[0]
          end
          messageto(msg.actor, out)
        end
      rescue
        messageto(msg.actor, I18n.t('plugin_youtube.yta.index_error'))
      end

      Thread.new do
        #local variables for this thread!
        actor = msg.actor
        Thread.current["user"]=msg.username
        Thread.current["process"]="youtube (yta)"

        messageto(actor, I18n.t('plugin_youtube.yta.times',:times => link.length.to_s))
        link.each do |l|
          messageto(actor, "#{I18n.t('plugin_youtube.yta.fetchconvert')} <a href=\"#{l}\">youtube</a>")
          @loader.get_files(l)
          if ( @loader.size > 0 ) then
            @@bot[:mpd].update(Conf.gvalue("plugin:youtube:folder:download").gsub(/\//,""))
            messageto(actor, I18n.t('plugin_youtube.db_update'))
            while @@bot[:mpd].status[:updating_db] do
              sleep 0.5
            end
            messageto(actor, I18n.t('plugin_youtube.db_update_done'))
            messageto(actor, "<b>#{I18n.t('plugin_youtube.yta.added')}</b>")
            while @loader.size > 0
              title = @loader.get_song
              begin
                @@bot[:mpd].add(Conf.gvalue("plugin:youtube:folder:download")+title[:name]+title[:extention])
                messageto(actor, "<br>#{title[:name]}")
              rescue
                messageto(actor, "<br>#{I18n.t('plugin_youtube.yta.notfound', :song => (title[:name]+title[:extention]))}<br>")
              end
            end
          else
            messageto(actor, I18n.t('plugin_youtube.badlink'))
          end
        end
      end
    end
  end

  private

  def find_youtube_song song
    songlist = []
    songs = `#{Conf.gvalue("plugin:youtube:youtube_dl:path")} --max-downloads #{Conf.gvalue("plugin:youtube:youtube_dl:maxresults")} --get-title --get-id "https://www.youtube.com/results?search_query=#{song}"`
    temp = songs.split(/\n/)
    while (temp.length >= 2 )
      songlist << [temp.pop , temp.pop]
    end
    return songlist
  end

end
