class Radiostream < Plugin

    def init(init)
        @bot = init
        if ( @bot[:mpd] != nil ) && ( @bot[:messages] != nil ) && ( @bot[:radiostream] == nil )
            @bot[:radiostream] = self
        end
        return @bot
        #nothing to init
    end
    
    def name
        if ( @bot[:mpd] == nil ) || ( @bot[:messages] == nil ) || ( @bot[:radiostream] == nil)
            "false"
        else    
            self.class.name
        end
    end
    
    def help(h)
        h += "<hr><span style='color:red;'>Plugin Radiostream</span><br />"
        h += "<b>#{@bot[:controlstring]}radiostream http-link</b> will try to get some music from icecast/shoutcast.<br />"
        h += "   this version does only understand .pls link files"
    end
   
    def handle_chat(msg, message)
        if message.start_with? "radiostream <a href=" 
            link = msg.message[msg.message.index('>') + 1 .. -1]
            link = link[0..link.index('<')-1]
            file = `wget -O - "#{link}"`
            if file[0..9] == "[playlist]"
                file.each_line do |line|
                    if line.start_with? ("File1=")
                        @bot[:mpd].add(line[6..-1].strip)
                    end
                end
            else
                @bot[:messages].text(msg.actor, "not a .pls file link.")
            end
        else
            @bot[:messages].text(msg.actor, "parameter must be a html link!")
        end
    end
    
end