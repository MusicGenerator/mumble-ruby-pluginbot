require_relative './helpers/StreamCheck.rb'
class Radiostream < Plugin

  def init(init)
    super
    if ( @@bot[:mpd] != nil ) && ( @@bot[:messages] != nil ) && ( @@bot[:radiostream] == nil )
      @@bot[:radiostream] = self
      begin
        @xspf = require 'crack'         #parse xspf playlists only if crack gem is installed
      rescue
        puts "if you install crack gem radiostream plugin also can parse xspf stream playlists." if @xspf == false 
      end
      @keylist = Array.new 
    end
    return @@bot
  end

  def name
    if ( @@bot[:mpd] == nil ) || ( @@bot[:messages] == nil ) || ( @@bot[:radiostream] == nil)
      "false"
    else    
      self.class.name
    end
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{@@bot[:controlstring]}radiostream URL</b> - Will try to forward the radio stream.<br>"
    h << "<b>#{@@bot[:controlstring]}choose shows list if remote playlist has more choices. (You will get informed if you can use this command).<br>"
    h << "<b>#{@@bot[:controlstring]}choose <i>number</i> choose stream.<br>"
    h << "   This early version understand URLs that end with .pls or such that are in fact .pls files."
    h << "   Some .m3u links or direct URLs get also in function now."
  end

  def handle_chat(msg, message)
    super
    if message.start_with?("radiostream <a href=") || message.start_with?("<a href=") 
      link = msg.message.match(/http[s]?:\/\/(.+?)\"/).to_s.chop
      @keylist.delete_if { |key| key[:user] == msg.actor }              #delete last search for this user
      Thread.new do
        user = msg.actor
        Thread.current["user"]=user
        Thread.current["process"]="radiostream"
        add_link( link, user )
        results = (@keylist.count { |key| key[:user] == msg.actor })
        if results > 1 then
          messageto(msg.actor, "There are #{results} results, please choose with choose command")
        else
          add = ""
          @keylist.each do |key|
            if key[:user]==user then
              add = key[:link]
            end
          end
          if add != "" then
            @@bot[:mpd].add(add) 
            messageto(msg.actor, "Added: #{add}")
          end
        end
      end
    end

    if message == "choose"
      counter = 0
      output = "You can choose from <br><table>"
      @keylist.each do |key|
        if key[:user] == msg.actor then
          output << ("<tr><td>#{counter.to_s}</td><td>#{key[:link]}</td></tr>")
          counter += 1
        end
      end
      output << "</table>"
      output = "There is nothing where you can choose from!" if counter == 0
      messageto(msg.actor, output)
    end

    if message.match (/choose (?:[\d{1,3}\ ?])+/)
      begin
        msg_parameters = message.split[1..-1].join(" ")
        id_list = msg_parameters.match(/(?:[\d{1,3}\ ?])+/)[0].split

        chooselist = Array.new                                          #generate chooselist first
        @keylist.each do |key|                                          
          if key[:user] == msg.actor then
            chooselist << key[:link]
          end
        end

        id_list.each do |id|
          @@bot[:mpd].add(chooselist[id.to_i])
          messageto(msg.actor, "Added #{chooselist[id.to_i]}")
        end

      rescue
        messageto(msg.actor, "Does not exist. :(")
      end
    end
  end

  private

  def add_link(link, user)

    decoded = false
    puts link
    file = `curl -g -L --max-time 3 "#{link}" `                #Load some data from link
    streaminfo = StreamCheck.new                            #init StreamCheck

    info = streaminfo.checkmp3(file)                        #check if mp3
    if info[:verified] != nil then                          #is mp3-stream?
      info[:link] = link                                    #add link to info
      decoded = true                                        #set decoded to true to prevent other checks    
    end

    if !decoded                                             #if it is no mp3 stream
      info = streaminfo.checkopus(file)                     #check if ogg
      if info[:verified] != nil then                        #is ogg-stream?
        info[:link] = link                                  #add link to info
        decoded = true                                      #set decodet to true to prevent other checks
      end  
    end

    if ( file[0..9] == "[playlist]" ) && !decoded           #if still not decoded check if is a .pls link
                                                            # seems to be an .pls link
      file.each_line do |line|
        if line.match (/File[0-9]{1,2}=.+/)                 #if a link found run check recursive
          add_link(line.sub(/File[0-9]{1,2}=/, '').strip, user)
        end
      end
    end
    
    if ( file[0..4] == "<?xml" ) && ( @xspf == true ) && !decoded                
                                                            #if still not decoded check if it is an xml file and crack gem is installed
      begin
        tracks = Crack::XML.parse(file)["playlist"]["trackList"]["track"]
        if tracks.size > 1
          tracks.each do |track|
            add_link(track["location"], user)
          end
        else
          add_link(tracks["location"], user)
        end
      rescue
        # no xspf!
      end
    end

    if !decoded                                             #if still not decoded test as m3u link
      file.each_line do |line|
        if ( line.start_with? "http://" ) || ( line.start_with? "https://")
          add_link(line.strip, user)                        #if it contains links in m3u manner
        end
      end
    end

    if ( decoded == true )                                  #if decoded add info to keylist
      info[:user]=user
      @keylist << info 
    end
  end
end
