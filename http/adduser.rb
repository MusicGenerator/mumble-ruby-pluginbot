#!/usr/bin/env ruby
require "cgi"
require "yaml"
require_relative "../helpers/conf.rb"
require_relative "../helpers/ClassExtend.rb"

HEADER =
'<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="de" lang="de">
<meta http-equiv="cache-control" content="no-cache">
<meta http-equiv="pragma" content="no-cache">
<meta http-equiv="expires" content=“0">
'
HEAD =
'<head>
  <title>Settings</title>
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<link type="text/css" rel="stylesheet" href="css/screen.css" />
  <script type="text/javascript" src="js/jquery-1.4.2.min.js"></script>
	<script type="text/javascript">
		$(\'html\').addClass(\'js\');
	</script>
  <script type="text/javascript" src="js/functions.js"></script>
  <script type="text/javascript">
    function fill(text) {
      var i;
      x = document.getElementsByName(\'input\')
      for (i = 0; i < x.length; i++) {
        x[i].style = "position:absolute; visibility:hidden; top:31px; left:19px;";
      }
      document.getElementById(text).style = "position:absolute; visibility:visible; top:31px; left:19px;";
      x = document.getElementsByTagName(\'li\');
      for (i = 0; i < x.length; i++) {
        x[i].style = "background-color: #ffffff;";
      }
      document.getElementById("listid"+text).style = "background-color: #e0e0ff;"
    }
    function hide(text) {
      document.getElementById(text).style = "position:absolute; visibility:hidden; top:31px; left:19px;";
    }
  </script>
</head>
'

#@description = YAML::load_file("config/config.description")

def margin(value)
  margin =""
  value.to_i.times do
    margin << " "
  end
  margin
end

def p_keyvalue(config,parent)
  config.each do |key, value|
    m = parent.split(":").count
    if value.is_a?(Hash) then
      puts "#{parent}#{key}</br>"
      p_keyvalue(value,"#{parent}#{key}:")
      puts "\n"
    else
      html = " "
      html << "#{margin(m)}#{key}=#{value}"
      puts "#{html}<br>\n"
    end
  end
end

def p_tree(config,parent)
  config.each do |key, value|
    if value.is_a?(Hash) then
      puts "<li><span>#{key}</span><ul>"
      p_tree(value,"#{parent}:#{key}")
      puts "</ul></li>"
    else
      puts "  <li id='listidshow#{parent}:#{key}'><a href=\"javascript:fill('show#{parent}:#{key}')\" title=\"#{value}\">#{key}</a></li>"
    end
  end
end

def p_input(config,parent)
  config.each do |key, value|
    if value.is_a?(Hash) then
      p_input(value,"#{parent}:#{key}")
    else
      puts "<div id='show#{parent}:#{key}' name='input' style='position:absolute; visibility:hidden; top:31px; left:19px;'>\n"
      if value.nil?
        puts " <label for='#{parent}#{value}'>#{key}<br><input id='#{parent}' name='#{parent}:#{key}' value='nil'>"
      else
        value = value.to_s.split(':').join('[:]')
        puts " <label for='#{parent}#{value}'>#{key}<br><input id='#{parent}' name='#{parent}:#{key}' value='#{value}'>"
      end
      puts "</label>\n</div>"
    end
  end
end

cgi = CGI.new
params = cgi.params
if params == {}
  Conf.load("../config/config.yml")
  Dir["../plugins/*.yml"].each do |f|
    Conf.load(f)
  end
else
  params.each do |key, value|
    value = value.join.split('[:]').join(':')
    value = value.to_i if value.to_i.to_s == value
    value = true if value == "true"
    value = false if value == "false"
    value = nil if value == "nil"
    Conf.svalue(key.to_s[1..-1], value)
  end
end
File.open("../../bot1_conf_done.yml", 'w') {|f| f.write Conf.get.to_yaml }

puts HEADER
puts HEAD
puts '
<body>
<div class="setup">
<p style="visibility:hidden;"><label>Setting<br><input></label></p>
<form>
<div class="node"><h2>Settings</h2>
<ul>
'
p_tree(Conf.get,"")

puts '
</ul>
</div>
<div class="edit">
'

p_input(Conf.get,"")
puts'

</div>
<input type="submit" value="ok">
</form>
</div>
</body>
</html>'
