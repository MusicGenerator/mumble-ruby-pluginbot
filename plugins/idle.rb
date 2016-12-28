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
    if  !@@bot[:bot].nil?
      self.class.name
    end
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}idletime</b> - Show current idle time of the bot.<br>"
    h
  end

  def handle_chat(msg, message)
    super
    if message == "idletime"
      status_message = "<br />Maximum idle time is set to: #{@@bot["plugin"]["idle"]["maxidletime"]} seconds.
                        <br />Idle action is: #{@@bot["plugin"]["idle"]["idleaction"]}."

      if @is_idle
        current_idle_time = (Time.now.getutc - @timestamp_idle_started).to_i
        privatemessage("<br />Current idle time is: #{current_idle_time.to_s} seconds. #{status_message}")
      else
        privatemessage("<br />The bot is currently not idle.#{status_message}")
      end
    end
  end
end
