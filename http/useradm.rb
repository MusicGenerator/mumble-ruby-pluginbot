#!/usr/bin/env ruby
require "yaml"
require "socket"
require_relative "../helpers/conf.rb"


def table_users(config,parent,user,out)
  config.each do |key, value|
    if value.is_a?(Hash) then
      table_users(value,"#{parent}:#{key}",user,out)
    else
      if parent.include? user
        out << "
          <tr id='tu#{user}'>
            <td>#{key}</td>
            <td>#{user}</td>
            <td>#{value}</td>
            <td><input type='checkbox' id='#{user}' name='#{user}:#{value}' value='#{key}'></td>
            <td></td>
          </tr>"
      end
    end
  end
  out
end

def get_users
  out = ""
  begin
    @s = TCPSocket.new 'localhost', 7750
    @s.puts "userhashes"
    users= @s.gets
    @s.close

    users.split(" ").each do |user|
      hash=user.split('|')[0]
      name=user.split('|')[1..-1].join
      out << "
          <tr id='serveruser'>
            <td>#{hash}</td>
            <td></td>
            <td>#{name}</td>
            <td><input type='checkbox' id='suadd' name='suadd:#{name}' value='#{hash}'></td>
            <td><input type='checkbox' id='ubann' name='ubann:#{name}' value='#{hash}'></td>
          </tr>"
    end
  rescue
    @error = "Warning: No Connection to RemoteUI Port<br>"
  end
  out
end


@error = ""
cgi = CGI.new
params = cgi.params
Conf.load("../../bot1_conf_done.yml")

if params != {}
  params.each do |key, value|
    Conf.svalue("main:user:superuser:#{value.join}",key[6..-1]) if key[0..4] == "suadd"
    Conf.svalue("main:user:banned:#{value.join}",key[6..-1]) if key[0..4] == "ubann"
    Conf.delsuperuser(value.join) if key[0..8]=="superuser"
    Conf.delbanneduser(value.join) if key[0..5]=="banned"
  end
end

begin
  File.open("../../bot1_conf_done.yml", 'w') {|f| f.write Conf.get.to_yaml }
rescue
  error << "Waring: Configuration-File is not writeable!<br>"
end


puts "
<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"
  \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">
<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"de\" lang=\"de\">
<meta http-equiv=\"cache-control\" content=\"no-cache\">
<meta http-equiv=\"pragma\" content=\"no-cache\">
<meta http-equiv=\"expires\" content=“0\">
<head>
  <title>User Administration</title>
	<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />
  <link type=\"text/css\" rel=\"stylesheet\" href=\"css/screen.css?v=%s\" />
</head>
<body>
  <div class=\"useradm\">
  <form>
    <h2>User Administration</h2>
    <div id=\"userlist\">
      <div id=\"server\">
        <h2>Users on Server</h2>
        <table>
          <tr>
            <th id=\"cert-hash\">Cert-Hash</th>
            <th></th>
            <th id=\"username\">Name</th>
            <th id=\"checkbox\">SuperUser</th>
            <th id=\"checkbox\">Bann</th>
          </tr>
          #{get_users}
        </table>
      </div>
      <div id=\"config\">
        <h2>Users in Configuration Setting</h2>
        <table>
          <tr>
            <th id=\"cert-hash\">Cert-Hash</th>
            <th>Type</th>
            <th id=\"username\">Name</th>
            <th id=\"checkbox\">delete</th>
            <th id=\"checkbox\"></th>
          </tr>
          #{table_users(Conf.get,'','superuser','')}#{table_users(Conf.get,'','banned','')}
        </table>
      </div>
      <p>
        <input type=\"submit\">
        <img src=\"img/arrow-sync.png\" alt=\"reload\" onclick=\"javascript:window.location.href='useradm.rb'\">
        <img src=\"img/arrow-shuffle.png\" alt=\"switch\" onclick=\"javascript:window.location.href='configset.rb'\">
      </p>
    </div>
  </form>
  <p>#{@error}</p>
</body>
</html>
" % Time.now
