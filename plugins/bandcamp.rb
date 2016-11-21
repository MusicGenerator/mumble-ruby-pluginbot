class Bandcamp < Plugin

  def init(init)
    super

    if ( !@@bot[:mpd].nil? ) && ( @@bot[:messages] ) && ( @@bot[:bandcamp].nil? )
      begin
        @destination = @@bot["plugin"]["mpd"]["musicfolder"] + @@bot["plugin"]["bandcamp"]["folder"]["download"]
        @temp = @@bot["main"]["tempdir"] + @@bot["plugin"]["bandcamp"]["folder"]["temp"]
        Dir.mkdir(@destination) unless File.exists?(@destination)
        Dir.mkdir(@temp) unless File.exists?(@temp)
      rescue
        debug "Error: bandcamp-Plugin didn't found settings for mpd music directory and/or your preferred temporary download directory"
        debug "See config/config.yml"
      end
      @ytdloptions = ""
      @consoleaddition = ""
      begin
        @ytdloptions = @@bot["plugin"]["bandcamp"]["youtube_dl"]["options"]
        @consoleaddition = @@bot["plugin"]["bandcamp"]["youtube_dl"]["prefixes"]
      rescue
      end
      @songlist = Queue.new
      @keylist = Array.new
      @@bot[:bandcamp] = self
    end
    @filetypes= ["ogg", "mp3", "mp2", "m4a", "aac", "wav", "ape", "flac"]
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
      h << "<b>#{@@bot["main"]["control"]["string"]}bandcamp <i>URL</i></b> - Will try to download the music from the given URL. Be aware that due to bandwidth limitations from bandcamp the bot downloads with the a maximum speed that is slightly higher than the streaming speed. Please be patient if you let the bot download a whole album :)<br>"
      h << "<b>#{@@bot["main"]["control"]["string"]}ytdl-version</b> - print used download helper version"
  end

  def handle_chat(msg, message)
    super

    if message == "ytdl-version"
      privatemessage("Bandcamp uses youtube-dl " + `#{@@bot["plugin"]["bandcamp"]["youtube_dl"]["path"]} --version`)
    end

    if message.start_with?("bandcamp <a href=") || message.start_with?("<a href=") then
      link = msg.message.match(/http[s]?:\/\/(.+?)\"/).to_s.chop
      if link.include? "bandcamp" then
        Thread.new do
          #local variables for this thread!
          actor = msg.actor
          Thread.current["user"]=actor
          Thread.current["process"]="bandcamp"

          messageto(actor, "Bandcamp is inspecting link: " + link + "...")
          get_song link
          if ( @songlist.size > 0 ) then
            @@bot[:mpd].update(@@bot["plugin"]["bandcamp"]["folder"]["download"].gsub(/\//,""))
            messageto(actor, "Waiting for database update complete...")

            while @@bot[:mpd].status[:updating_db] do
              sleep 0.5
            end

            messageto(actor, "Update done.")
            while @songlist.size > 0
              song = @songlist.pop
              messageto(actor, song)
              @@bot[:mpd].add(@@bot["plugin"]["bandcamp"]["folder"]["download"]+song)
            end
          else
            messageto(actor, "Bandcamp: The link contains nothing interesting.")
          end
        end
      end
    end
  end

  def get_song(site)
    if ( site.include? "bandcamp.com/" ) then
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

      debug site

      filename = `#{@@bot["plugin"]["bandcamp"]["youtube_dl"]["path"]} --get-filename #{@ytdloptions} -i -o \"#{@temp}%(title)s\" "#{site}"`
      output =`nice -n20 #{@consoleaddition} #{@@bot["plugin"]["bandcamp"]["youtube_dl"]["path"]} #{@ytdloptions} --write-thumbnail -x --audio-format best -o \"#{@temp}%(title)s.%(ext)s\" \"#{site}\" `     #get icon
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
