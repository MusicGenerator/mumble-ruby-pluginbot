require "yaml"
require "socket"
require_relative "../helpers/conf.rb"


def command_bot(command)
  users = ""
  begin
    @s = TCPSocket.new 'localhost', 7750
    @s.puts command
    out= @s.gets
    @s.close
  rescue
    @error = "Warning: No Connection to RemoteUI Port<br>"
    out = "No connection to RemoteUI Port"
  end
  out.force_encoding('utf-8')
end

def table_config_users(config,parent,user,out)
  config.each do |key, value|
    if value.is_a?(Hash) then
      table_config_users(value,"#{parent}:#{key}",user,out)
    else
      if parent.include? user
        puts "
          <tr id='tu#{user}'>
            <td>#{key}</td>
            <td>#{user}</td>
            <td>#{value}</td>
            <td><button id='#{user}' value='#{key}' onclick=\"javascript:deluser('#{parent}#{key}')\">delete</button></td>
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
      <td><input type='checkbox' id='suadd' name='suadd:#{name}' value='#{hash}'></td>
      <td><input type='checkbox' id='ubann' name='ubann:#{name}' value='#{hash}'></td>
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
        out << " <label for='#{parent}#{value}'>#{key}<br><input id='#{parent}' name='#{parent}:#{key}' value='nil'>"
      else
        value = value.to_s.split(':').join('[:]')
        out << " <label for='#{parent}#{value}'>#{key}<br><input id='#{parent}' name='#{parent}:#{key}' value='#{value}'>"
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


@error = ""
out = ""
cgi = CGI.new
params = cgi.params


tableserveruser = '
<table>
  <tr>
    <th id=\"cert-hash\">Cert-Hash</th>
    <th>Type</th>
    <th id=\"username\">Name</th>
    <th id=\"checkbox\">SuperUser</th>
    <th id=\"checkbox\">bann</th>
  </tr>
'
tableconfiguser = '
<table>
  <tr>
    <th id=\"cert-hash\">Cert-Hash</th>
    <th>Type</th>
    <th id=\"username\">Name</th>
    <th id=\"checkbox\">delete</th>
    <th id=\"checkbox\"></th>
  </tr>
'
tableend = '</table>'

if params != {}
  params.each do |key, value|
    cmd = key.to_s
    case cmd
    when "showconfig"
      load_main_config
      load_personal_config
      puts "<h2 onclick='collapse_tree()'>Settings</h2><ul><li>#{p_tree(Conf.get,"","")}</ul></li>"

    when "getedits"
      load_main_config
      load_personal_config
      puts "<form action=\"save.rb\" method=\"post\">#{p_input(Conf.get,"","")}<input type=\"submit\" id=\"submit\" class=\"submit\"></form>"

    when "getserverusers"
      puts "#{tableserveruser}"
      table_server_users(command_bot("userhashes"))
      puts "#{tableend}"

    when "getbannedusers"
      load_personal_config
      puts "#{tableconfiguser}"
      table_config_users(Conf.get,'','banneduser','')
      puts "#{tableend}"

    when "getsuperusers"
        load_personal_config
        puts "#{tableconfiguser}"
        table_config_users(Conf.get,'','superuser','')
        puts "#{tableend}"

    when "command"
      puts command_bot(value)

    else
      puts "super"
      load_main_config
      load_personal_config
      value = value.join.split('[:]').join(':')
      value = value.to_i if value.to_i.to_s == value
      value = true if value == "true"
      value = false if value == "false"
      value = nil if value == "nil"
      Conf.svalue(key.to_s[1..-1], value)
      begin
        #write only differences to Standard Config to Overwrite Config.
        diff = standard.deep_changes(Conf.get.clone)
        File.open("../../bot1_conf.yml", 'w') {|f| f.write diff.to_yaml }
      rescue
        @error << "Warning: Configuration-File is not writeable! (no changes saved)<br>"
      end
    end
  end
end
