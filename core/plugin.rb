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
      logger "WARN: Sending message to user #{@user} failed. Maybe left server before we try to send. Message:'#{message}'"
    end
  end
  def messageto(actor, message)
    begin
      @@bot[:cli].text_user(actor, message)
    rescue
      logger "WARN: Sending message to user #{actor} failed. Maybe left server before we try to send. Message:'#{message}'"
    end
  end
  def channelmessage(message)
    begin
      @@bot[:cli].text_channel(@@bot[:cli].me.current_channel, message)
    rescue
      logger "WARN: Sending message to channel '#{@@bot[:cli].me.current_channel}' failed. Message:'#{message}'"
    end
  end

  def logger(logline)
    if Conf.gvalue("debug")
      logline="#{Time.new.to_s} : #{logline}\n"
      if Conf.gvalue("main:logfile") == nil
        puts logline.chomp
      else
        written = IO.write(Conf.gvalue("main:logfile"), logline, mode: 'a')
        if written != logline.length
          puts "ERROR: Logfile (#{Conf.gvalue("main:logfile")}) is not writeable, logging to stdout instead"
          puts logline.chomp
          Conf.svalue("main:logfile", nil) 
        end
      end
    end
  end

end
