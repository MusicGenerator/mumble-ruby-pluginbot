class Bandcamp < Plugin

  def init(init)
    super

    if ( @@bot[:mpd] != nil ) && ( @@bot[:messages] != nil ) && ( @@bot[:bandcamp] == nil )
      begin
        @bandcampfolder = @@bot[:mpd_musicfolder] + @@bot[:bandcamp_downloadsubdir]
        @tempbandcampfolder = @@bot[:main_tempdir] + @@bot[:bandcamp_tempsubdir]

        Dir.mkdir(@bandcampfolder) unless File.exists?(@bandcampfolder)
        Dir.mkdir(@tempbandcampfolder) unless File.exists?(@tempbandcampfolder)
      rescue
        puts "Error: bandcamp-Plugin didn't found settings for mpd music directory and/or your preferred temporary download directory"
        puts "See pluginbot_conf.rb"
      end
      begin
        @ytdloptions = @@bot[:bandcamp_youtubedl_options]
      rescue
        @ytdloptions = "" 
      end
      @consoleaddition = "" 
      @consoleaddition = @@bot[:bandcamp_commandlineprefixes] if @@bot[:bandcamp_commandlineprefixes] != nil
      @songlist = Queue.new
      @keylist = Array.new
      @@bot[:bandcamp] = self
    end
    @filetypes= ["ogg", "mp3", "mp2", "m4a", "aac", "wav", "ape", "flac"]
    return @@bot
  end

  def name
      if ( @@bot[:mpd] == nil ) || ( @@bot[:bandcamp] == nil)
          "false"
      else    
          self.class.name
      end
  end

  def help(h)
      h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
      h << "<b>#{@@bot[:controlstring]}bandcamp <i>URL</i></b> - Will try to download the music from the given URL. Be aware that due to bandwidth limitations from bandcamp the bot downloads with the a maximum speed that is slightly higher than the streaming speed. Please be patient if you let the bot download a whole album :)<br>"
      h << "<b>#{@@bot[:controlstring]}ytdl-version</b> - print used download helper version"
  end

  def handle_chat(msg, message)
    super

    if message == "ytdl-version"
      privatemessage("Bandcamp uses youtube-dl " + `#{@@bot[:bandcamp_youtubedl]} --version`) 
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
            @@bot[:mpd].update(@@bot[:bandcamp_downloadsubdir].gsub(/\//,"")) 
            messageto(actor, "Waiting for database update complete...")

            while @@bot[:mpd].status[:updating_db] != nil do
              sleep 0.5
            end

            messageto(actor, "Update done.")
            while @songlist.size > 0 
              song = @songlist.pop
              messageto(actor, song)
              @@bot[:mpd].add(@@bot[:bandcamp_downloadsubdir]+song)
            end
          else
            messageto(actor, "Bandcamp: The link contains nothing interesting.") if @@bot[:bandcamp_stream] == nil
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

        finaldirectory = "#{@bandcampfolder}/#{albumname}"
        Dir.mkdir(finaldirectory) unless File.exists?(finaldirectory)
      else #no album
        albumname = ""
        finaldirectory = "#{@bandcampfolder}"
      end

      puts site

      filename = `#{@@bot[:bandcamp_youtubedl]} --get-filename #{@ytdloptions} -i -o \"#{@tempdownloadfoler}%(title)s\" "#{site}"`
      output =`nice -n20 #{@consoleaddition} #{@@bot[:bandcamp_youtubedl]} #{@ytdloptions} --write-thumbnail -x --audio-format best -o \"#{@tempbandcampfolder}%(title)s.%(ext)s\" \"#{site}\" `     #get icon
      filename.split("\n").each do |name|
        @filetypes.each do |ending|
          if File.exist?("#{@tempbandcampfolder}#{name}.#{ending}")
            system ("nice -n20 #{@consoleaddition} convert \"#{@tempbandcampfolder}#{name}.jpg\" -resize 320x240 \"#{@bandcampfolder}#{name}.jpg\" ")
            # Mixin tags without recode on standard

            system ("nice -n20 #{@consoleaddition} cp \"#{@tempbandcampfolder}#{name}.#{ending}\" \"#{finaldirectory}/#{name}.#{ending}\"") if !File.exist?("#{finaldirectory}/#{name}.#{ending}")

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
