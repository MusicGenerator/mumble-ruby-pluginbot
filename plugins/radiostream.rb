require_relative './helpers/StreamCheck.rb'
class Radiostream < Plugin
  
  def init(init)
    super
    if ( @@bot[:mpd] != nil ) && ( @@bot[:messages] != nil ) && ( @@bot[:radiostream] == nil )
      @@bot[:radiostream] = self
    end
      
    @keylist = Array.new
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
    h += "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h += "<b>#{@@bot[:controlstring]}radiostream URL</b> - Will try to forward the radio stream.<br>"
    h += "<b>#{@@bot[:controlstring]}choose shows list if remote playlist has more choices. (You will get informed if you can use this command).<br>"
    h += "<b>#{@@bot[:controlstring]}choose <i>number</i> choose stream.<br>"
    h += "   This early version understand URLs that end with .pls or such that are in fact .pls files."
    h += "   Some .m3u links or direct URLs get also in function now."
  end
 
  def handle_chat(msg, message)
    super
    if message.start_with?("radiostream <a href=") || message.start_with?("<a href=")
      link = msg.message.match(/http[s]?:\/\/(.+?)\"/).to_s.chop
      messageto(msg.actor, add_link(link, msg.actor))
    end
    
    if message == "choose"
      counter = 0
      begin
        output = "You can choose from <br><table>"
        @keylist[msg.actor].each do |lnk|
          output << ("<tr><td>#{counter.to_s}</td><td>#{lnk}</td></tr>")
          counter += 1
        end
        output << "</table>"
      rescue
        output = "There is nothing where you can choose from!"
      end
      messageto(msg.actor, output)
    end
    
    if message.match (/choose [0-9]{1,2}/)
      begin
        msg_parameters = message.split[1..-1].join(" ")
        id_list = msg_parameters.match(/[0-9]+/)[0].split
        id_list.each do |id|
          @@bot[:mpd].add(@keylist[msg.actor][id.to_i])
          messageto(msg.actor, "Added #{@keylist[msg.actor][id.to_i]}")
        end
      rescue
        messageto(msg.actor, "Does not exist. :(")
      end
    end
  end
  
  def add_link(link, user)
    added = ""
    file = `curl -L --max-time 3 "#{link}" `
    links = []
    
    if file[0..9] == "[playlist]"
      # seems to be an .pls link
      file.each_line do |line|
        puts line
        if line.match (/File[0-9]{1,2}=.+/)
          links.push(line.sub(/File[0-9]{1,2}=/, '').strip)
        end
      end
    else
      file.each_line do |line|
        # check if it is a m3u playlistlinkfile
        if ( line.start_with? "http://" ) || ( line.start_with? "https://")
          if line.include? ".pls"
            add_link line, user 
          else
            puts line.strip
            links.push(line.strip)
          end
        end
      end
      
      # finally check if source is direct stream
      streaminfo = StreamCheck.new
      info = streaminfo.checkmp3(file)
      if info[:verified] != nil then
        @@bot[:mpd].add(link)
        added << link
        info.each do |key, value|
          added << ( '<br>' + key.to_s.upcase + ": " + value.to_s.upcase )
        end
      end

      info = streaminfo.checkopus(file)
      if info[:verified] != nil then
        @@bot[:mpd].add(link)
        added << link
        info.each do |key, value|
          added << ( '<br>' + key.to_s.upcase + ": " + value.to_s.upcase )
        end
      end
    end
    if links.size == 1 then
      added += "Added #{links[0]}"
      @@bot[:mpd].add(links[0])
    end
    if links.size > 1 then
      added += "There are #{links.size} links in remote playlist, choose one with choose command."
      @keylist[user] = links
    end
    return added
  end
    
end

