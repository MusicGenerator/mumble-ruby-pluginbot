require "yaml"
require "socket"
require_relative "../helpers/conf.rb"


def command_bot(command, port=7750)
  users = ""
  begin
    @s = TCPSocket.new 'localhost', port
    @s.puts command
    out= @s.gets
    @s.close
  rescue
    @error = "Warning: No Connection to RemoteUI Port<br>"
    out = "No connection to RemoteUI Port"
  end
  out.force_encoding('utf-8')
end

def table_config_users(config,parent,out)
  config.each do |key, value|
    if value.is_a?(Hash) then
      table_config_users(value,"#{parent}:#{key}",out)
    else
      if parent.include? "user"
        userstring = parent.split(':')
        certhash = userstring.pop
        type = userstring.pop
        puts "
          <tr id='tu#{type}'>
            <td>#{certhash}</td>
            <td><img src='/img/#{type}.png'></td>
            <td>#{key}</td>
            <td><button value='#{key}' onclick=\"javascript:deluser('#{parent}')\">delete</button></td>
            <td></td>
          </tr>"
      end
    end
  end
end

def table_server_users(users)
  users.split("\t").each do |user|
    hash=user.split('|')[0]
    name=user.split('|')[1..-1].join
    puts "
    <tr class='user'>
      <td>#{hash}</td>
      <td></td>
      <td>#{name}</td>
      <td><select name='user' onchange=\"javascript:userdrop(this);\">
        <option value=''>choose</option>
        <option value='suadd=#{hash}:#{name}'>SuperUser</option>
        <option value='ubann=#{hash}:#{name}'>ban</option>
        <option value='white=#{hash}:#{name}'>whitelist</option>
      </select></td>
    </tr>"
  end
end

def p_tree(config,parent,out)
  config.each do |key, value|
    if value.is_a?(Hash) then
      out << "<li><span>#{key}</span><ul>"
      p_tree(value,"#{parent}:#{key}",out)
      out << "</ul></li>"
    else
      out << "  <li id='listidshow#{parent}:#{key}'><a href=\"javascript:fill('show#{parent}:#{key}')\" title=\"#{value}\">#{key}</a></li>"
    end
  end
  out
end

def p_input(config,parent,out)
  config.each do |key, value|
    if value.is_a?(Hash) then
      p_input(value,"#{parent}:#{key}",out)
    else
      out << "<div id='show#{parent}:#{key}' name='input' class='input'>\n"
      if value.nil?
        out << " <label for='#{parent}#{value}'>#{key}<br><input class='textinput' id='#{parent}' name='#{parent}:#{key}' value='nil'>"
      else
        value = value.to_s.split(':').join('[:]')
        out << " <label for='#{parent}#{value}'>#{key}<br><input class='textinput' id='#{parent}' name='#{parent}:#{key}' value='#{value}'>"
      end
      out << "</label>\n</div>"
    end
  end
  out
end

def load_main_config
  Conf.load("../config/config.yml")
  Dir["../plugins/*.yml"].each do |f|
    Conf.load(f)
  end
  #Standard Configuration loaded.
  @standard=Conf.get.clone
end

def load_personal_config
  begin
    Conf.load("../../bot1_conf.yml")
  rescue
    @error << "Warning: Personal Configuration not found (will written after any change)!"
  end
end

def find_bot_port
  port = 7750 #Start at Standard Port.
  while port < 7800
    begin
      test = TCPSocket.new 'localhost', port
      test.puts "hello"
      @port.push(port) if test.gets == "mrpb"
      test.close
    rescue
    end
    port += 1
  end
  @port.length
end

@error = ""
@port = []
out = ""
cgi = CGI.new
params = cgi.params


tableuser = '
<table class="legend">
  <tr><th>User</th><th>Symbol</th></tr>
  <tr><td>SuperUser</td><td><img src="/img/superuser.png"></td></tr>
  <tr><td>Whitelisted</td><td><img src="/img/whitelisted.png"></td></tr>
  <tr><td>Banned User</td><td><img src="/img/banned.png"></td></tr>
</table>
<table class="userlist">
  <tr>
    <th id=\"cert-hash\">Cert-Hash</th>
    <th>Type</th>
    <th id=\"username\">Name</th>
    <th id=\"checkbox\">Action</th>
  </tr>
'
tableend = '</table>'

if params != {}
  cgi.has_key?('port') ? port = cgi.params["port"].join.to_i : port=7750
  if cgi.has_key?('showconfig')
    load_main_config
    load_personal_config
    puts "<h2 onclick='collapse_tree()'>Settings</h2><ul><li>#{p_tree(Conf.get,"","")}</ul></li>"
  end

  if cgi.has_key?('getedits')
    load_main_config
    load_personal_config
    puts "<form action=\"save.rb\" method=\"post\">#{p_input(Conf.get,"","")}<input type=\"submit\" id=\"submit\" class=\"submit\"></form>"
  end


  if cgi.has_key?('getconfigusers')
    load_personal_config
    puts "#{tableuser}"
    table_config_users(Conf.get,'','')
    table_server_users(command_bot("userhashes",port))
    puts "#{tableend}"
  end

  if cgi.has_key?('command')
    case cgi['command']
    when "getports"
      find_bot_port
      @port.each do |port|
        puts "<input type=\"radio\" id=\"botselect\" name=\"#{port}\" value=\"#{port}\">"
        puts "<label for=\"#{port}\">BotPort:#{port}</label>"
      end

    when "logfile"

      lines = command_bot("logfile",port).split("<br>")
      out = ""
      lines.each do |line|
        columns= line.split(":")
        out << "<span class\"log_time}\">#{columns[0..2].join}</span>\n"
        case columns[3].to_s
        when " OK"
          out << "<span class\"log_status_ok\">"
        when " ERROR"
          out << "<span class\"log_status_error\">"
        when " DEBUG"
          out << "<span class\"log_status_debug\">"
        when " INFO"
          out << "<span class\"log_status_info\">"
        else
          out << "<span class\"log_status_else\">"
        end
        out << "#{columns[3]}</span>\n"
        out << "<span class=\"log_status_message\">#{columns[4..-1].join}</span><br>\n"
      end
      puts out
    else
      command_bot(cgi['command'],port)
    end
  end

  if cgi.has_key?('suadd')
    load_personal_config
    Conf.svalue("main:user:superuser:#{cgi['suadd']}","")
    begin
      diff = Conf.get.clone
      File.open("../../bot1_conf.yml", 'w') {|f| f.write diff.to_yaml }
    rescue
      puts "Warning: Configuration-File is not writeable!<br>"
    end
    puts "suadd"
  end

  if cgi.has_key?('ubann')
    load_personal_config
    Conf.svalue("main:user:banned:#{cgi['ubann']}","")
    begin
      diff = Conf.get.clone
      File.open("../../bot1_conf.yml", 'w') {|f| f.write diff.to_yaml }
    rescue
      puts "Warning: Configuration-File is not writeable!<br>"
    end
    puts "ubann"
  end

  if cgi.has_key?('white')
    load_personal_config
    Conf.svalue("main:user:whitelisted:#{cgi['white']}","")
    begin
      diff = Conf.get.clone
      File.open("../../bot1_conf.yml", 'w') {|f| f.write diff.to_yaml }
    rescue
      puts "Warning: Configuration-File is not writeable!<br>"
    end
    puts "white"
  end

  if cgi.has_key?('delete')
    load_personal_config
    Conf.delkey(cgi['delete'])
    begin
      diff = Conf.get.clone
      File.open("../../bot1_conf.yml", 'w') {|f| f.write diff.to_yaml }
    rescue
      puts "Warning: Configuration-File is not writeable!<br>"
    end
    puts "done"
  end

end
