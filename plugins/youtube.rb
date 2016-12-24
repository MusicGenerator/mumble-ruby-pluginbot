require 'cgi'

class Youtube < Plugin

  def init(init)
    super
    if ( @@bot[:mpd] ) && ( @@bot[:messages] ) && ( @@bot[:youtube].nil? )
      logger("INFO: INIT plugin #{self.class.name}.")
      begin
        @destination = @@bot["plugin"]["mpd"]["musicfolder"] + @@bot["plugin"]["youtube"]["folder"]["download"]
        @temp = @@bot["main"]["tempdir"] + @@bot["plugin"]["youtube"]["folder"]["temp"]

        Dir.mkdir(@destination) unless File.exists?(@destination)
        Dir.mkdir(@temp) unless File.exists?(@temp)
      rescue
        logger "Error: Youtube-Plugin didn't find settings for mpd music directory and/or your preferred temporary download directory."
        logger "See ../config/config.yml"
      end
      begin
        @ytdloptions = @@bot["plugin"]["youtube"]["options"]
      rescue
        @ytdloptions = ""
      end
      @consoleaddition = ""
      @consoleaddition = @@bot["plugin"]["youtube"]["youtube_dl"]["prefixes"] if @@bot["plugin"]["youtube"]["youtube_dl"]["prefixes"]
      @executable = "#"
      @executable = @@bot["plugin"]["youtube"]["youtube_dl"]["path"] if @@bot["plugin"]["youtube"]["youtube_dl"]["path"]

      @songlist = Queue.new
      @keylist = Array.new
      @@bot[:youtube] = self
    end
    @filetypes= ["ogg", "mp3", "mp2", "m4a", "aac", "wav", "ape", "flac", "opus"]
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
    h << "<b>#{@@bot["main"]["control"]["string"]}ytlink <i>URL</i></b> - Will try to download the music from the given URL.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}yts keywords</b> - Will search on Youtube for one or more keywords and print the results to you.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}ytstream <i>URL</i></b> - Stream audio from a video instead of downloading a video. May take some time because of buffering.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}yta <i>number</i> <i>number2</i> <i>number3</i></b> - Let the bot download the given song(s) from the list you got via <i>#{@@bot["main"]["control"]["string"]}yts</i>.<br>Instead of a specific number or multiple numbers, write <b>#{@@bot["main"]["control"]["string"]}yta <i>all</i></b> to let the bot download all found songs.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}ytdl-version</b> - print used download helper version"
  end

  def handle_chat(msg, message)
    super

    if message == "ytdl-version"
        privatemessage("Youtube uses youtube-dl " + `#{@executable} --version`)
    end

    if message.start_with?("ytlink <a href=") || message.start_with?("<a href=") then
      link = msg.message.match(/http[s]?:\/\/(.+?)\"/).to_s.chop
      if ( link.include? "www.youtube.com/" ) || ( link.include? "www.youtu.be/" ) || ( link.include? "m.youtube.com/" ) then
        workingdownload = Thread.new {
          #local variables for this thread!
          actor = msg.actor
          Thread.current["actor"]=actor
          Thread.current["process"]="youtube (download)"

          messageto(actor, "Youtube is inspecting link: " + link + "...")
          get_song(link).each do |error|
            messageto(actor, error)
          end
          if ( @songlist.size > 0 ) then
            @@bot[:mpd].update(@@bot["plugin"]["youtube"]["folder"]["download"].gsub(/\//,""))
            messageto(actor, "Waiting for database update complete...")

            while @@bot[:mpd].status[:updating_db] do
              sleep 0.5
            end

            messageto(actor, "Update done.")
            while @songlist.size > 0
              song = @songlist.pop
              messageto(actor, song)
              @@bot[:mpd].add(@@bot["plugin"]["youtube"]["folder"]["download"]+song)
            end
          else
            messageto(actor, "Youtube: The link contains nothing interesting.")
          end
        }
      end
    end

    if message.split[0] == 'yts'
      search = message[4..-1]
      if !(( search.nil? ) || ( search == "" ))
        Thread.new do
          Thread.current["user"]=msg.actor
          Thread.current["process"]="youtube (yts)"

          messageto(msg.actor, "searching for \"#{search}\", please be patient...")
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
        messageto(msg.actor, "won't search for nothing!")
      end
    end

    if message.split[0] == 'ytstream'
      link = msg.message.match(/http[s]?:\/\/(.+?)\"/).to_s.chop
      link.gsub!(/<\/?[^>]*>/, '')
      link.gsub!("&amp;", "&")

      messageto(msg.actor, "Youtube is inspecting link: " + link + "...")

      streams = `#{@executable} -g "#{link}"`
      streams.each_line do |line|
        line.chop!
        @@bot[:mpd].add line if line.include? "mime=audio/mp4"
      end

      messageto(msg.actor, "Added \"#{link}\" to the queue.")
    end

    if message.split[0] == 'yta'
      begin
        out = "<br>Going to download the following songs:<br />"
        msg_parameters = message.split[1..-1].join(" ")
        link = []

        if msg_parameters.match(/(?:[\d{1,3}\ ?])+/) # User gave us at least one id or multiple ids to download.
          id_list = msg_parameters.match(/(?:[\d{1,3}\ ?])+/)[0].split
          id_list.each do |id|
            downloadid = @keylist[msg.actor][id.to_i]
            logger downloadid.inspect
            out << "ID: #{id}, Name: \"#{downloadid[1]}\"<br>"
            link << "https://www.youtube.com/watch?v="+downloadid[0]
          end

          messageto(msg.actor, out)
        end

        if msg_parameters == "all"
          @keylist[msg.actor].each do |downloadid|
            out << "Name: \"#{downloadid[1]}\"<br>"
            link << "https://www.youtube.com/watch?v="+downloadid[0]
          end
          messageto(msg.actor, out)
        end
      rescue
        messageto(msg.actor, "[error](youtube-plugin)- index number is out of bounds!")
      end

      workingdownload = Thread.new {
        #local variables for this thread!
        actor = msg.actor
        Thread.current["user"]=actor
        Thread.current["process"]="youtube (yta)"

        messageto(actor, "do #{link.length.to_s} time(s)...")
        link.each do |l|
            messageto(actor, "fetch and convert")
            get_song(l).each do |error|
                @@bot[:messages.text(actor, error)]
            end
        end
        if ( @songlist.size > 0 ) then
          @@bot[:mpd].update(@@bot["plugin"]["youtube"]["folder"]["download"].gsub(/\//,""))
          messageto(actor, "Waiting for database update complete...")

          while @@bot[:mpd].status[:updating_db] do
            sleep 0.5
          end

          messageto(actor, "Update done.")
          out = "<b>Added:</b><br>"

          while @songlist.size > 0
            song = @songlist.pop
            begin
              @@bot[:mpd].add(@@bot["plugin"]["youtube"]["folder"]["download"]+song)
              out << song + "<br>"
            rescue
              out << "fixme: " + song + " not found!<br>"
            end
          end
          messageto(actor, out)
        else
          messageto(actor, "Youtube: The link contains nothing interesting.")
        end
      }
    end
  end

  private

  def find_youtube_song song
    songlist = []
    songs = `#{@executable} --max-downloads #{@@bot["plugin"]["youtube"]["youtube_dl"]["maxresults"]} --get-title --get-id "https://www.youtube.com/results?search_query=#{song}"`
    temp = songs.split(/\n/)
    while (temp.length >= 2 )
      songlist << [temp.pop , temp.pop]
    end
    return songlist
  end

  def get_song(site)
    error = Array.new

    if ( site.include? "www.youtube.com/" ) || ( site.include? "www.youtu.be/" ) || ( site.include? "m.youtube.com/" ) then
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
            if @@bot["plugin"]["youtube"]["to_mp3"].nil?
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
    return error
  end
end
