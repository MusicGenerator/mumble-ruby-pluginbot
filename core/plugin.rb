class Plugin
  def self.plugins
    @plugins ||= []
  end

  def self.inherited(klass)
    @plugins ||= []

    @plugins << klass
  end

  # Usually a good idea for debugging if you have lots of methods
  def handle_chat(msg, message)
    @user = msg.actor
    #raise "#{self.class.name} doesn't implement `handle_chat`!"
  end

  def handle_command(command)
    #raise "#{self.class.name} doesn't implement `handle_command`!"
  end

  def handle_response
    #
  end

  def handle_help(text)
    text << "#{self.class.name} doesn't implement a help"
  end

  def ticks(time)
    #enable periodic timer for plugins
  end

  def init(init)
    @@bot = init
  end

  private
  def processmessage(message)
    # count lines
    # for future use (send long messages in smaller parts)
    lines = message.count("<br>") + message.count("<tr>")
    puts lines
    return message
  end
  def privatemessage(message)
    begin
      @@bot[:cli].text_user(@user, message)
    rescue
      puts "Sending message to user #{@user} failed. Maybe left server before we try to send."
    end
  end
  def messageto(actor, message)
    begin
      @@bot[:cli].text_user(actor, message)
    rescue
      puts "Sending message to user #{actor} failed. Maybe left server before we try to send."
    end
  end
  def channelmessage(message)
    begin
      @@bot[:cli].text_channel(@@bot[:cli].me.current_channel, message)
    rescue
      puts "Sending message to channel #{@@bot[:cli].me.current_channel} failed. ->should never happen<-"
    end
  end


  def debug(message)
    if @@bot[:debug]
      puts "Plugin[#{self.class.name}] "+message
    end
  end
end
