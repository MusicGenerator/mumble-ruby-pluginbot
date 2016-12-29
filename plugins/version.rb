class Version < Plugin

  def init(init)
    super
    logger("INFO: INIT plugin #{self.class.name}.")
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
    h << "<b>#{@@bot["main"]["control"]["string"]}branch</b> - Show the used branch name.<br>"
    h << "<b>#{@@bot["main"]["control"]["string"]}commiturl</b> - Print a clickable commit URL based on the assumption that it is a commit in the main repository.<br>"
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

    if message == "branch"
      branch = `git rev-parse --abbrev-ref HEAD`
      privatemessage("Branch: #{branch.to_s}")
    end

    if message == "commiturl"
      versionlong = `git rev-parse HEAD`
      privatemessage("<a href='https://github.com/dafoxia/mumble-ruby-pluginbot/commit/#{versionlong.to_s}'>#{versionlong.to_s}</a>")
    end
  end
end
