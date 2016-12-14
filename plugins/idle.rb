class Idle < Plugin

  def init(init)
    super
    @@bot[:bot] = self
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
      idle_timeframe = Time.now.getutc - @timestamp_idle_started

      if (idle_timeframe) >= @@bot["plugin"]["idle"]["maxidletime"]
        if @@bot["plugin"]["idle"]["idleaction"] == "deafen"
          @@bot[:cli].me.deafen true if !@@bot[:cli].me.deafened?
          @is_idle = false
        end

        if @@bot["plugin"]["idle"]["idleaction"] == "channel"
          @@bot[:cli].join_channel(@@bot["mumble"]["channel"])
          @is_idle = false
        end
      end
    end
  end

  def name
    self.class.name
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}idletime</b> - Show current idle time of the bot.<br>"
    h
  end

  def handle_chat(msg, message)
    super
    if message == "idletime"
      if @is_idle
        current_idle_time = Time.now.getutc - @timestamp_idle_started
        privatemessage("Current idle time is: #{current_idle_time.to_s}<br />Maximum idle time is: #{@@bot["plugin"]["idle"]["maxidletime"]}")
      else
        privatemessage("The bot is not idle currently.<br />")
      end
    end
  end
end
