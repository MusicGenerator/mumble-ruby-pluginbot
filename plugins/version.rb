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
    h
  end

  def handle_chat(msg, message)
    super
    if message == "version"
      begin
        gitversionshort = `git rev-parse --short HEAD`.chomp
        gitversionlong = `git rev-parse HEAD`.chomp
        gitdate = `git log -n1 --format="%at"`.chomp
        gitbranch = `git rev-parse --abbrev-ref HEAD`.chomp
        gittag = `git describe --tags`.chomp
        gitcommiturl = `git rev-parse HEAD`.chomp

        send = "Some git information:<br />
                Version (short): #{gitversionshort.to_s}<br />
                Version (long): #{gitversionlong.to_s}<br />
                Date of last commit: #{Time.at(gitdate.to_i).utc}<br />
                Branch: #{gitbranch.to_s}<br />
                Tag: #{gittag.to_s}<br />
                Commiturl: <a href='https://github.com/MusicGenerator/mumble-ruby-pluginbot/commit/#{gitversionlong.to_s}'>#{gitversionlong.to_s}</a>"

        privatemessage(send)
      rescue
        privatemessage("Something went wrong with git...")
      end
    end
  end
end
