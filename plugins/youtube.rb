require 'cgi'

class Youtube < Plugin

  def init(init)
    super
    if ( @@bot[:mpd] != nil ) && ( @@bot[:messages] != nil ) && ( @@bot[:youtube] == nil )
      begin
        @youtubefolder = @@bot[:mpd_musicfolder] + @@bot[:youtube_downloadsubdir]
        @tempyoutubefolder = @@bot[:main_tempdir] + @@bot[:youtube_tempsubdir]

        Dir.mkdir(@youtubefolder) unless File.exists?(@youtubefolder)
        Dir.mkdir(@tempyoutubefolder) unless File.exists?(@tempyoutubefolder)
      rescue
        puts "Error: Youtube-Plugin didn't find settings for mpd music directory and/or your preferred temporary download directory"
        puts "See pluginbot_conf.rb"
      end
      begin
        @ytdloptions = @@bot[:youtube_youtubedl_options]
      rescue
        @ytdloptions = "" 
      end
      @consoleaddition = "" 
      @consoleaddition = @@bot[:youtube_commandlineprefixes] if @@bot[:youtube_commandlineprefixes] != nil
      @songlist = Queue.new
      @keylist = Array.new
      @@bot[:youtube] = self
    end
    @filetypes= ["ogg", "mp3", "mp2", "m4a", "aac", "wav", "ape", "flac", "opus"]
    return @@bot
  end

  def name
    if ( @@bot[:mpd] == nil ) || ( @@bot[:youtube] == nil)
      "false"
    else
      self.class.name
    end
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{@@bot[:controlstring]}ytlink <i>URL</i></b> - Will try to download the music from the given URL.<br>"
    h << "<b>#{@@bot[:controlstring]}yts keywords</b> - Will search on Youtube for one or more keywords and print the results to you.<br>"
    h << "<b>#{@@bot[:controlstring]}yta <i>number</i> <i>number2</i> <i>number3</i></b> - Let the bot download the given song(s) from the list you got via <i>#{@@bot[:controlstring]}yts</i>.<br>Instead of a specific number or multiple numbers, write <b>#{@@bot[:controlstring]}yta <i>all</i></b> to let the bot download all found songs.<br>"
    h << "<b>#{@@bot[:controlstring]}ytdl-version</b> - print used download helper version"
  end

  def handle_chat(msg, message)
    super

    if message == "ytdl-version"
        privatemessage("Youtube uses youtube-dl " + `#{@@bot[:youtube_youtubedl]} --version`) 
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
            @@bot[:mpd].update(@@bot[:youtube_downloadsubdir].gsub(/\//,"")) 
            messageto(actor, "Waiting for database update complete...")

            while @@bot[:mpd].status[:updating_db] != nil do
              sleep 0.5
            end

            messageto(actor, "Update done.")
            while @songlist.size > 0 
              song = @songlist.pop
              messageto(actor, song)
              @@bot[:mpd].add(@@bot[:youtube_downloadsubdir]+song)
            end
          else
            messageto(actor, "Youtube: The link contains nothing interesting.") if @@bot[:youtube_stream] == nil
          end
        }
      end
    end

    if message.split[0] == 'yts'
      search = message[4..-1]
      if !(( search == nil ) || ( search == "" ))
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

    if message.split[0] == 'yta'
      begin
        out = "<br>Going to download the following songs:<br />"
        msg_parameters = message.split[1..-1].join(" ")
        link = []

        if msg_parameters.match(/(?:[\d{1,3}\ ?])+/) # User gave us at least one id or multiple ids to download.
          id_list = msg_parameters.match(/(?:[\d{1,3}\ ?])+/)[0].split
          id_list.each do |id|
            downloadid = @keylist[msg.actor][id.to_i]
            puts downloadid.inspect
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
          @@bot[:mpd].update(@@bot[:youtube_downloadsubdir].gsub(/\//,"")) 
          messageto(actor, "Waiting for database update complete...")

          while @@bot[:mpd].status[:updating_db] != nil do
            sleep 0.5
          end

          messageto(actor, "Update done.")
          out = "<b>Added:</b><br>"

          while @songlist.size > 0 
            song = @songlist.pop
            begin
              @@bot[:mpd].add(@@bot[:youtube_downloadsubdir]+song)
              out << song + "<br>"
            rescue
              out << "fixme: " + song + " not found!<br>"
            end
          end
          messageto(actor, out)
        else
          messageto(actor, "Youtube: The link contains nothing interesting.") if @@bot[:youtube_stream] == nil
        end
      }
    end
  end

  private 

  def find_youtube_song song
    songlist = []
    songs = `nice -n20 #{@@bot[:youtube_youtubedl]} --get-title --get-id "https://www.youtube.com/results?search_query=#{song}"`
    temp = songs.split(/\n/)
    while (temp.length >= 2 )
      songlist << [temp.pop , temp.pop]
    end
    return songlist
  end

  def get_song(site)
    error = Array.new
    if ( site.include? "www.youtube.com/" ) || ( site.include? "www.youtu.be/" ) || ( site.include? "m.youtube.com/" ) then
      site.gsub!(/<\/?[^>]*>/, '')
      site.gsub!("&amp;", "&")
      if @@bot[:youtube_stream] == nil
        filename = `#{@@bot[:youtube_youtubedl]} --get-filename #{@ytdloptions} -i -o \"#{@tempdownloadfoler}%(title)s\" "#{site}"`
        output =`nice -n20 #{@consoleaddition} #{@@bot[:youtube_youtubedl]} #{@ytdloptions} --write-thumbnail -x --audio-format best -o \"#{@tempyoutubefolder}%(title)s.%(ext)s\" \"#{site}\" `     #get icon
        output.each_line do |line|
          error << line if line.include? "ERROR:"
        end
        filename.split("\n").each do |name|
          @filetypes.each do |ending|
            if File.exist?("#{@tempyoutubefolder}#{name}.#{ending}")
              system ("nice -n20 #{@consoleaddition} convert \"#{@tempyoutubefolder}#{name}.jpg\" -resize 320x240 \"#{@youtubefolder}#{name}.jpg\" ")
              if @@bot[:youtube_to_mp3] == nil
                # Mixin tags without recode on standard
                system ("nice -n20 #{@consoleaddition} ffmpeg -i \"#{@tempyoutubefolder}#{name}.#{ending}\" -acodec copy -metadata title=\"#{name}\" \"#{@youtubefolder}#{name}.#{ending}\"") if !File.exist?("#{@youtubefolder}#{name}.#{ending}")
                @songlist << name.split("/")[-1] + ".#{ending}"
              else
                # Mixin tags and recode it to mp3 (vbr 190kBit)
                system ("nice -n20 #{@consoleaddition} ffmpeg -i \"#{@tempyoutubefolder}#{name}.#{ending}\" -codec:a libmp3lame -qscale:a 2 -metadata title=\"#{name}\" \"#{@youtubefolder}#{name}.mp3\"") if !File.exist?("#{@youtubefolder}#{name}.mp3")
                @songlist << name.split("/")[-1] + ".mp3"
              end
            end
          end
        end
      else
        streams = `#{@@bot[:youtube_youtubedl]} -g "#{site}"`
        streams.each_line do |line|
          line.chop!
          @@bot[:mpd].add line if line.include? "mime=audio/mp4"
        end
      end
    end
    return error
  end
end
