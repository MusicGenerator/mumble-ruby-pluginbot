class Null < Plugin

    def init(init)
        super
        @@bot[:bot] = self
        return @@bot
        #nothing to init
    end
    
    def name
        self.class.name
    end
    
    def help(h)
        #no help for nothing!
        h
    end
   
    def handle_chat(msg, message)
        #this plugin does nothing!
    end
end