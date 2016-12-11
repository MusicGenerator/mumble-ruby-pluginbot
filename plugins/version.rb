class Version < Plugin

  def init(init)
    super
    @@bot[:bot] = self
    return @@bot
    #nothing to init
  end

  def name
    self.class.name
  end

  def help(h)
    h << "<hr><span style='color:red;'>Plugin #{self.class.name}</span><br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}version</b> - Show the used Bot version.<br>"
    h
  end

  def handle_chat(msg, message)
    super
    if message == "version"
      versionshort = `git rev-parse --short HEAD`
      versionlong = `git rev-parse HEAD`
      date = `git log -n1 --format="%at"`
      privatemessage("Version: #{versionshort.to_s} / #{versionlong.to_s} / #{Time.at(date.to_i).utc}")
    end
  end
end
