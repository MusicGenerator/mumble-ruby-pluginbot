class Radiostream < Plugin

    def init(init)
        super
        if ( @@bot[:mpd] != nil ) && ( @@bot[:messages] != nil ) && ( @@bot[:radiostream] == nil )
            @@bot[:radiostream] = self
        end
        return @@bot
        #nothing to init
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
        h += "   This early version does only understand URLs that end with .pls or such that are in fact .pls files."
    end
   
    def handle_chat(msg, message)
        super
        if message.start_with? "radiostream <a href=" 
            link = msg.message[msg.message.index('>') + 1 .. -1]
            link = link[0..link.index('<')-1]
            messageto(msg.actor, add_link(link, ""))
        end
    end
    
    def add_link(link, added)
        file = `curl -L --max-time 1 "#{link}" `
        if file[0..9] == "[playlist]"
            # seems to be an .pls link
            file.each_line do |line|
                if line.start_with? ("File1=")
                    @@bot[:mpd].add(line[6..-1].strip)
                    added += line[6..-1].strip + "<br>"
                end
            end
        else
            file.each_line do |line|
                # check if it is a m3u playlistlinkfile
                if ( line.start_with? "http://" ) || ( line.start_with? "https://")
                    puts added
                    if line.include? ".pls"
                        add_link line, added 
                    else
                        @@bot[:mpd].add(line.strip)
                        added += line.strip + "<br>"
                    end
                end
            end
        end
        return added
    end
    
end