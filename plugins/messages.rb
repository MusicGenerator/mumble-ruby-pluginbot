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
    super
    if @@bot[:messages] == nil
      @priv_notify = {}
      @@bot[:messages] = self
    end
    return @@bot
  end

  def name
    if @@bot[:messages] != nil
      "Messages"
    else
      self.class.name
    end
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{@@bot[:controlstring]}+ #(<i>Hashtag</i>)</b> - Subscribe to a notification.<br>"
    h << "<b>#{@@bot[:controlstring]}- #(<i>Hashtag</i>)</b> - Unsubscribe from a notification.<br>"
    h << "You can choose one or more of the following values:<br>"
    h << "volume, random, update, single, xfade, consume, repeat, state<br>"
    h << "<b>#{@@bot[:controlstring]}*</b> - List subscribed notifications.<br>"
    h << "<br /><b>Example:</b> To get a message when the repeat mode changes send the command \"#{@@bot[:controlstring]}+ #repeat\""
  end

  def handle_chat(msg, message)
    super
    @priv_notify[msg.actor] = 0 if @priv_notify[msg.actor].nil?
    if message[2] == '#'
      message.split.each do |command|
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
      send = ""
      send << " #volume" if (@priv_notify[msg.actor] & Cvolume) > 0
      send << " #update" if (@priv_notify[msg.actor] & Cupdating_db) > 0
      send << " #random" if (@priv_notify[msg.actor] & Crandom) > 0
      send << " #single" if (@priv_notify[msg.actor] & Csingle) > 0
      send << " #xfade" if (@priv_notify[msg.actor] & Cxfade) > 0
      send << " #repeat" if (@priv_notify[msg.actor] & Crepeat) > 0
      send << " #state" if (@priv_notify[msg.actor] & Cstate) > 0
      if send != ""
        send = "You listen to following MPD-Channels:" + send + "." 
      else
        send << "You listen to no MPD-Channels"
      end
      @@bot[:cli].text_user(msg.actor, send)
    end
  end

  def sendmessage (message, messagetype)
    channelmessage( message) if ( @@bot[:chan_notify] & messagetype) != 0
    if !@priv_notify.nil?
      @priv_notify.each do |user, notify| 
        begin
          @@bot[:cli].text_user(user,message) if ( notify & messagetype) != 0
        rescue

        end
      end
    end
  end

end
