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
    h << "<b>#{Conf.gvalue("main:control:string")}version</b> - #{I18n.t("plugin_version.help.version")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}branch</b> - #{I18n.t("plugin_version.help.branch")}<br>"
    h << "<b>#{Conf.gvalue("main:control:string")}commiturl</b> - #{I18n.t("plugin_version.help.commiturl")}.<br>"
    h
  end

  def handle_chat(msg, message)
    super
    if message == "version"
      versionshort = `git rev-parse --short HEAD`
      versionlong = `git rev-parse HEAD`
      date = `git log -n1 --format="%at"`

      privatemessage("#{I18n.t("plugin_version.version")} #{versionshort.to_s} / #{versionlong.to_s} / #{Time.at(date.to_i).utc}")
    end

    if message == "branch"
      branch = `git rev-parse --abbrev-ref HEAD`
      privatemessage("#{I18n.t("plugin_version.branch")} #{branch.to_s}")
    end

    if message == "commiturl"
      versionlong = `git rev-parse HEAD`.chomp
      privatemessage("<a href='https://github.com/MusicGenerator/mumble-ruby-pluginbot/commit/#{versionlong.to_s}'>#{versionlong.to_s}</a>")
    end
  end
end
