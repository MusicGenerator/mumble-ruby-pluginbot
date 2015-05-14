class Messages < Plugin

    Cvolume =      0x01 #send message when volume change
    Cupdating_db = 0x02 #send message when database update
    Crandom =      0x04 #send message when random mode changed
    Csingle =      0x08 #send message when single mode changed
    Cxfade =       0x10 #send message when crossfading changed
    Cconsume =     0x20 #send message when consume-mode changed
    Crepeat =      0x40 #send message when repeat-mode changed
    Cstate =       0x80 #send message when state changes

    def init(init)
        @bot = init
        if @bot[:messages] == nil
            @priv_notify = {}
            @bot[:messages] = self
            @mqueue = Queue.new
            @uqueue = Queue.new
            @lastmessage = Time.now
            @messagecount = 0
            domessages = Thread.new {
                while true == true 
                    if ( @messagecount < 10 ) && ( @mqueue.length > 0 ) 
                        @bot[:cli].text_user(@uqueue.pop,@mqueue.pop) 
                        @messagecount += 1 if ( ( Time.now - @lastmessage ) < 10 )
                        @lastmessage = Time.now
                    end
                    @messagecount = 0 if ( Time.now - @lastmessage ) > 11
                    sleep (0.1)
                end
            }
        end
        return @bot
    end

    def name
        if @bot[:messages] != nil
            "messages"
        else
            self.class.name
        end
    end

    def help(h)
        h += "<hr><span style='color:red;'>Plugin MESSAGES</span><br />"
        h += "<b>#{@bot[:controlstring]}+ #(<i>Hashtag</i>)</b> add a notification.<br />"
        h += "<b>#{@bot[:controlstring]}- #(<i>Hashtag</i>)</b> remove a notification.<br />"
        h += "You can choose one or more of this:<br />"
        h += "volume, random, update, single, xfade, consume, repeat, state<br />"
    end

    def handle_chat(msg, message)
        @priv_notify[msg.actor] = 0 if @priv_notify[msg.actor].nil?
        if message[2] == '#'
            message.split.each do |command|
                puts command
                case command
                when "#volume"
                    add = Cvolume
                when "#update"
                    add = Cupdating_db
                when "#random"
                    add = Crandom
                when "#single"
                    add = Csingle
                when "#xfade"
                    add = Cxfade
                when "#consume"
                    add = Cconsume
                when "#repeat"
                    add = Crepeat
                when "#state"
                    add = Cstate
                else
                    add = 0
                end
                @priv_notify[msg.actor] |= add if message[0] == '+' 
                @priv_notify[msg.actor] &= ~add if message[0] == '-' 
            end
        end
        if message == '*' && !@priv_notify[msg.actor].nil?
            send = "You listen to following MPD-Channels:"
            send += " #volume" if (@priv_notify[msg.actor] & Cvolume) > 0
            send += " #update" if (@priv_notify[msg.actor] & Cupdating_db) > 0
            send += " #random" if (@priv_notify[msg.actor] & Crandom) > 0
            send += " #single" if (@priv_notify[msg.actor] & Csingle) > 0
            send += " #xfade" if (@priv_notify[msg.actor] & Cxfade) > 0
            send += " #repeat" if (@priv_notify[msg.actor] & Crepeat) > 0
            send += " #state" if (@priv_notify[msg.actor] & Cstate) > 0
            send += "."
            @bot[:cli].text_user(msg.actor, send)
        end
    end
    
    def sendmessage (message, messagetype)
        @bot[:cli].text_channel(@bot[:cli].me.current_channel, message) if ( @bot[:chan_notify] & messagetype) != 0
        if !@priv_notify.nil?
            @priv_notify.each do |user, notify| 
                begin
                    @bot[:cli].text_user(user,message) if ( notify & messagetype) != 0
                rescue
                
                end
            end
        end
    end
    
    def text (user, message)
        @mqueue << message
        @uqueue << user
    end
end