#!/usr/bin/env ruby
require "yaml"
require "socket"
require_relative "../helpers/conf.rb"


def command_bot(command)
  out = ""
  begin
    @s = TCPSocket.new 'localhost', 7750
    @s.puts command
    users= @s.gets
    @s.close
  rescue
    @error = "Warning: No Connection to RemoteUI Port<br>"
  end
  users
end


@error = ""
cgi = CGI.new
params = cgi.params

if params != {}
  params.each do |key, value|
    command_bot(value)
  end
end
logfile =""
logfile << "#{command_bot("logfile")}<br>"
logfile << @error


puts "
<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"
  \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">
<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"de\" lang=\"de\">
<meta http-equiv=\"cache-control\" content=\"no-cache\">
<meta http-equiv=\"pragma\" content=\"no-cache\">
<meta http-equiv=\"expires\" content=“0\">
<head>
  <title>Bot Administration</title>
	<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />
  <link type=\"text/css\" rel=\"stylesheet\" href=\"css/screen.css?v=%s\" />
</head>
<body>
  <div class=\"setup\">
    <form>
      <h2>Bot Administration</h2>
      <div id=\"userlist\">
        <div id=\"server\">
          <input type=\"radio\" value=\"stop\" name=\"bot\">Stop Bot<b>
        </div>
        <div id=\"config\">
          #{logfile}
        </div>
        <div class=\"buttons\">
          <input type=\"submit\" value=\"Ok\">
          <img src=\"img/arrow-sync.png\" alt=\"reload\" onclick=\"javascript:window.location.href='useradm.rb'\">
          <img src=\"img/arrow-shuffle.png\" alt=\"switch\" onclick=\"javascript:window.location.href='configset.rb'\">
        </div>
      </div>
    </form>
  </div>
  <p>#{@error}</p>
</body>
</html>
" % Time.now
