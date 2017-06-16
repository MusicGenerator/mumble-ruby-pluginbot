class Null < Plugin

  def init(init)
    super
    if @@bot[:null].nil?
      @@bot[:null] = self
    end
    return @@bot
    #nothing to init
  end

  def name
    if !@@bot[:null].nil?
      self.class.name
    else
      "false"
    end
  end

  def help(h)
    #no help for nothing!
    h
  end

  def handle_chat(msg, message)
    #this plugin does nothing!
  end
end
