class Idle < Plugin

  def init(init)
    super
    # prevent multible initiation.
    if @@bot[:idle].nil?
      logger("INFO: INIT plugin #{self.class.name}.")
      @@bot[:idle] = self
    end
    return @@bot
  end

  def ticks(time)
    if @@bot[:cli].me.muted?
      if !@is_idle
        @timestamp_idle_started = Time.now.getutc
        @is_idle = true
      end
    else
      # Reset timer
      @is_idle = false
    end

    if @is_idle == true
      idle_timeframe = (Time.now.getutc - @timestamp_idle_started).to_i

      if (idle_timeframe) >= Conf.gvalue("plugin:idle:maxidletime").to_i
        if Conf.gvalue("plugin:idle:idleaction") == "deafen"
          @@bot[:cli].me.deafen true if !@@bot[:cli].me.deafened?
          @is_idle = false
          logger("DEBUG: maxidletime reached. Deafening self.")
        end

        if Conf.gvalue("plugin:idle:idleaction") == "channel"
          @@bot[:cli].join_channel(Conf.gvalue("mumble:channel"))
          @is_idle = false
          logger("DEBUG: maxidletime reached. Switching to mumble:channel.")
        end
      end
    end
  end

  def name
    if  !@@bot[:bot].nil?
      self.class.name
    end
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{Conf.gvalue("main:control:string")}idletime</b> - #{I18n.t "plugin_idle.help.idletime"}<br>"
    h
  end

  def handle_chat(msg, message)
    super
    if message == "idletime"
      if @is_idle
        current_idle_time = (Time.now.getutc - @timestamp_idle_started).to_i
        privatemessage(I18n.t("plugin_idle.ideling", :ideling => current_idle_time.to_s, :idletime => Conf.gvalue("plugin:idle:maxidletime"), :idleaction => Conf.gvalue("plugin:idle:idleaction")))
      else
        privatemessage(I18n.t("plugin_idle.working", :idletime =>Conf.gvalue("plugin:idle:maxidletime"), :idleaction => Conf.gvalue("plugin:idle:idleaction")))
      end
    end
  end
end
