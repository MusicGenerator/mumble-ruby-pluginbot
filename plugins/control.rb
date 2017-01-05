class Control < Plugin

  def init(init)
    super
    if @@bot[:mpd]
      logger("INFO: INIT plugin #{self.class.name}.")
      @@bot[:control] = self
      @historysize = 20
      Conf.svalue("main:automute_if_alone", false) if Conf.gvalue("main:automute_if_alone").nil?
      Conf.svalue("main:control:historysize", 20) if Conf.gvalue("main:control:historysize").nil?
      @history = Array.new
      @muted = false
      #@@bot[:cli].mute false
      @stopped_because_unregisterd = false                              #used to determine if bot should get back in playstate
      @playing  = !@@bot[:mpd].paused?
      # Register for permission denied messages
      @@bot[:cli].on_permission_denied do |msg|
        nopermission(msg)
      end

      # Register for user state changes
      @@bot[:cli].on_user_state do |msg|
        userstate(msg)
      end
    end

    state_handling_if_alone

    return @@bot
  end

  def name
    if (@@bot[:mpd].nil? == true) || (@historysize.nil? == true)
      "false"
    else
      self.class.name
    end
  end

  # Timer Method called by Main
  def ticks(time)
    if @stopped_because_unregisterd == true                             #if bot is stopped itself
      me = @@bot[:cli].me
      allregistered = true
      @@bot[:cli].users.values.find do |u|
        allregistered = false if ( u.channel_id == me.channel_id ) && (u.user_id.nil?) && (u.name != me.name)
      end                                                               #check if a unregisterd user is still in channel
      if allregistered == true                                          #if all users registerd
        @@bot[:mpd].play                                                #start to play
        @stopped_because_unregisterd = false                            #clear flag
      end
    end
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{Conf.gvalue("main:control:string")}ch</b> - #{I18n.t("plugin_control.help.ch")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}debug</b> - #{I18n.t("plugin_control.help.debug")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}gotobed</b> - #{I18n.t("plugin_control.help.gotobed")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}wakeup</b> - #{I18n.t("plugin_control.help.wakeup")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}follow</b> - #{I18n.t("plugin_control.help.follow")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}unfollow</b> - #{I18n.t("plugin_control.help.unfollow")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}stick</b> - #{I18n.t("plugin_control.help.stick")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}unstick</b> - #{I18n.t("plugin_control.help.unstick")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}history</b> - #{I18n.t("plugin_control.help.history", :historysize => @historysize)}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}automute</b> - #{I18n.t("plugin_control.help.automute")}<br>"
  end

  def nopermission(msg)
    @follow = false
    @alreadyfollowing = false
    begin
      Thread.kill(@following) if @following
      @alreadyfollowing = false
    rescue TypeError
	  logger "No following thread but try to kill. #{$!}"
    end
  end

  def state_handling_if_alone()
    me = @@bot[:cli].me

    # Count users in my channel ...
    user_count = 0
    me_in = 0
    me_in = me.channel_id
    @@bot[:cli].users.values.select do |user|
      user_count += 1 if ( user.channel_id == me_in )
    end
    # if i'm alone
    if ( user_count < 2 ) && ( Conf.gvalue("main:automute_if_alone") == true )
      # if I'm playing then pause play and save that I've stopped myself

      #During bot start there is no mpd plugin loaded yet...
      if @@bot[:mpd]
        if @@bot[:mpd].paused? == false
          @@bot[:mpd].pause = true
          @playing = false
        end
      end
      # mute myself and save that I've done it myself
      selfmute true
    else
      # only unmute me if I've muted myself before
      selfmute false
      # start playing only I've stopped myself
      if @playing == false
        @@bot[:mpd].pause = false
        @playing = true
      end
    end
  end

  def userstate(msg)
    #msg.session = session_id of the target
    #msg.actor = session_id of user who did something on someone, if self done, both is the same.
    me = @@bot[:cli].me
    msg_target = @@bot[:cli].users[msg.session]
    if ( me.current_channel ) && ( msg.channel_id )
      # get register status of user
      if msg_target.user_id.nil?
        sender_is_registered = false
      else
        sender_is_registered = true
      end

      # If user is in my channel and is unregistered then pause playing if stop_on_unregistered_users is enabled.
      if ( me.current_channel.channel_id == msg_target.channel_id ) && ( Conf.gvalue("main:stop_on_unregistered") == true ) && ( sender_is_registered == false )  && ( @@bot[:mpd].playing? == true )
        current = @@bot[:mpd].current_song
        if current.file.include? "://" #If yes, it is probably some kind of a stream.
          @@bot[:mpd].stop
          action = I18n.t("plugin_control.status.stopped")
        else
          #if @@bot[:mpd].paused? == false
            @@bot[:mpd].pause = true
            action = I18n.t("plugin_control.status.paused")
          #end
        end
        @@bot[:cli].text_channel(@@bot[:cli].me.current_channel, "<span style='color:red;'>#{I18n.t("plugin_control.unreg_enter", :action => action)}</span>")
        @stopped_because_unregisterd = true
      end

      state_handling_if_alone
    end
  end

  def handle_chat(msg, message)
    super
    # Put message in Messagehistory and pop old's if size exceeds max. historysize.
    @history << msg
    @history.shift if @history.length > @historysize

    if message == 'ch'
      if @@bot[:cli].me.current_channel.channel_id.to_i == msg.channel_id.to_i
        privatemessage( I18n.t("plugin_control.ch.brain"))
      else
        @@bot[:cli].text_channel(@@bot[:cli].me.current_channel, I18n.t("plugin_control.ch.going", :user => msg.username))
        @@bot[:cli].join_channel(msg.channel_id)

        #additionally do a "wakeup"
        @@bot[:mpd].pause = false
        @@bot[:cli].me.deafen false if @@bot[:cli].me.deafened?
        selfmute false
      end
    end
    if message == 'debug'
      privatemessage("<span style='color:red;font-size:30px;'>#{I18n.t("plugin_control.debug")}</span>")
    end

    if message == 'gotobed'
      if Conf.gvalue("mumble:channel")
        @@bot[:cli].join_channel(Conf.gvalue("mumble:channel"))
        @@bot[:mpd].pause = true
        @@bot[:cli].me.deafen true
      begin
        Thread.kill(@following)
        @alreadyfollowing = false
        Thread.kill(@sticked)
        @alreadysticky = false
      rescue
      end
    else
      privatemessage( I18n.t("plugin_control.gotobed.error") )
      end
    end

    if message == 'wakeup'
      @@bot[:mpd].pause = false
      @@bot[:cli].me.deafen false if @@bot[:cli].me.deafened?
      selfmute false
    end

    if message == 'follow'
      if @alreadyfollowing == true
        privatemessage( I18n.t("plugin_control.follow.newuser"))
        @alreadyfollowing = false
        begin
          Thread.kill(@following)
          @alreadyfollowing = false
        rescue TypeError
          logger "#{$!}"
        end
      else
        privatemessage( I18n.t("plugin_control.follow.user"))
      end
      @follow = true
      @alreadyfollowing = true
      currentuser = msg.actor
      @following = Thread.new {
      begin
        Thread.current["user"] = currentuser
        Thread.current["process"] = "control (following)"
        while @follow == true do
          if (@@bot[:cli].me.current_channel != @@bot[:cli].users[currentuser].channel_id)
            @@bot[:cli].join_channel(@@bot[:cli].users[currentuser].channel_id)
          end
          sleep 0.5
        end
      rescue
        logger "#{$!}"

        @alreadyfollowing = false
        Thread.kill(@following)
      end
      }
    end

    if message == 'unfollow'
      if @follow == false
        privatemessage( I18n.t("plugin_control.unfollow.nok"))
      else
        privatemessage( I18n.t("plugin_control.unfollow.ok"))
        @follow = false
        @alreadyfollowing = false
        begin
          Thread.kill(@following)
          @alreadyfollowing = false
        rescue TypeError
          logger "#{$!}"
          privatemessage( I18n.t("plugin_control.unfollow.error", :control => Conf.gvalue("main:control:string")))
        end
      end
    end

    if message == 'stick'
      if @alreadysticky == true
        privatemessage( I18n.t("plugin_control.stick.sticked"))
        @alreadysticky = false
        begin
          Thread.kill(@sticked)
          @alreadysticky = false
        rescue TypeError
          logger "#{$!}"
        end
      else
        privatemessage( I18n.t("plugin_control.stick.sticking"))
      end
      @sticky = true
      @alreadysticky = true
      @sticked = Thread.new {
      Thread.current["user"]=msg.actor
      Thread.current["process"]="control/sticking"

      while @sticky == true do
        if @@bot[:cli].me.current_channel == msg.channel_id
          sleep(1)
        else
          begin
            @@bot[:cli].join_channel(msg.channel_id)
            sleep(1)
          rescue
            @alreadysticky = false
            @@bot[:cli].join_channel(@@bot[:mumbleserver_targetchannel])
            Thread.kill(@sticked)
            logger "#{$!}"
          end
        end
      end
      }
    end

    if message == 'unstick'
      if @sticky == false
        privatemessage( I18n.t("plugin_control.unstick.sticked"))
      else
        privatemessage( I18n.t("plugin_control.unstick.free"))
        @sticky = false
        @alreadysticky = false
        begin
          Thread.kill(@sticked)
        rescue TypeError
          logger "#{$!}"
        end
      end
    end

    if message == 'history'
      history = @history.clone
      out = "<table><tr><th>#{I18n.t("plugin_control.history.command")}</th><th>#{I18n.t("plugin_control.history.user")}</th></tr>"
      loop do
        break if history.empty?
        histmessage = history.shift
        out << "<tr><td>#{histmessage.message}</td><td>#{histmessage.username}</td></tr>"
      end
      out << "</table>"
      privatemessage( out)
    end

    if message == 'automute'
      if Conf.gvalue("main:automute_if_alone") == false
        privatemessage( I18n.t("plugin_control.automute.enabled"))
        Conf.svalue("main:automute_if_alone", true)
      else
        privatemessage( I18n.t("plugin_control.automute.disabled"))
        Conf.svalue("main:automute_if_alone", false)
      end
    end
  end

  private

  def selfmute(mute)
    if mute != @muted
      @muted = !@muted
      @@bot[:cli].mute @muted
    end
  end
end
