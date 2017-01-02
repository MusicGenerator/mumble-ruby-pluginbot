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
    if @@bot[:messages].nil?
      logger("INFO: INIT plugin #{self.class.name}.")
      @priv_notify = Hash.new(0)
      @@bot[:messages] = self
    end
    return @@bot
  end

  def name
    if @@bot[:messages]
      "Messages"
    else
      self.class.name
    end
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{Conf.gvalue("main:control:string")}+ #(<i>Hashtag</i>)</b> - #{I18n.t("plugin_messages.help.subscribe")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}- #(<i>Hashtag</i>)</b> - #{I18n.t("plugin_messages.help.unsubscribe")}<br>"
    h << "#{I18n.t("plugin_messages.help.values")}<br>"
    h << "volume, random, update, single, xfade, consume, repeat, state<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}*</b> - #{I18n.t("plugin_messages.help.list")}<br>"
    h << "<br />#{I18n.t("plugin_messages.help.example", :controlstring => Conf.gvalue("main:control:string"))}"
  end

  def handle_chat(msg, message)
    super
    #@priv_notify[msg.actor] = 0 if @priv_notify[msg.actor].nil?
    # we don't need above anymore because Hash is now defaulted to 0
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
    if message == '*' && @priv_notify[msg.actor]
      send = ""
      send << " #volume" if (@priv_notify[msg.actor] & Cvolume) > 0
      send << " #update" if (@priv_notify[msg.actor] & Cupdating_db) > 0
      send << " #random" if (@priv_notify[msg.actor] & Crandom) > 0
      send << " #single" if (@priv_notify[msg.actor] & Csingle) > 0
      send << " #xfade" if (@priv_notify[msg.actor] & Cxfade) > 0
      send << " #repeat" if (@priv_notify[msg.actor] & Crepeat) > 0
      send << " #state" if (@priv_notify[msg.actor] & Cstate) > 0
      if send != ""
        send = I18n.t("plugin_messages.star.listen") + send + "."
      else
        send << I18n.t("plugin_messages.star.nolisten")
      end
      @@bot[:cli].text_user(msg.actor, send)
    end
  end

  def sendmessage (message, messagetype)
    channelmessage( message) if ( Conf.gvalue("main:channel_notify").to_i & messagetype) != 0
    if @priv_notify
      @priv_notify.each do |user, notify|
        begin
          @@bot[:cli].text_user(user,message) if ( notify & messagetype) != 0
        rescue

        end
      end
    end
  end

end
