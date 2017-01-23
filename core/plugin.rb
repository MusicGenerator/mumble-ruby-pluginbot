class Plugin
  def self.plugins
    @plugins ||= []
  end

  def initialize
    @@logger ||= []
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

  def self.getlogsize
    begin
      @@logger.length
    rescue
      0
    end
  end

  def self.getlog
    @@logger.shift if @@logger.length >= 1
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
      @@logger.push "#{logline} (#{self.class.name})"
    end
  end

  def is_banned(userhash)
    if Conf.gvalue("main:user:banned").nil?
      return false
    else
      if Conf.gvalue("main:user:banned").has_key?("#{userhash}")
        return true
      else
        return false
      end
    end
  end

  def is_superuser(userhash)
    if Conf.gvalue("main:user:superuser").nil?
      return false
    else
      if Conf.gvalue("main:user:superuser").has_key?("#{userhash}")
        return true
      else
        return false
      end
    end
  end

  def is_whitelisted(userhash)
    if Conf.gvalue("main:user:whitelisted").nil?
      return false
    else
      if Conf.gvalue("main:user:whitelisted").has_key?("#{userhash}")
        return true
      else
        return false
      end
    end
  end

end
