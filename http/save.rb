require "cgi"
require "yaml"
require_relative "../helpers/conf.rb"
require_relative "../helpers/ClassExtend.rb"

@error = ""

cgi = CGI.new
params = cgi.params
Conf.load("../config/config.yml")
Dir["../plugins/*.yml"].each do |f|
  Conf.load(f)
end
#Standard Configuration loaded.
standard=Conf.get.clone

# load overwrite config at last
begin
  Conf.load("../../bot1_conf.yml")
rescue
  @error << "Warning: Personal Configuration not found (will written after any change)!"
end
if params != {}
  params.each do |key, value|
    value = value.join.split('[:]').join(':')
    value = value.to_i if value.to_i.to_s == value
    value = true if value == "true"
    value = false if value == "false"
    value = nil if value == "nil"
    Conf.svalue(key.to_s[1..-1], value)
  end
end

begin
  #write only differences to Standard Config to Overwrite Config.
  diff = standard.deep_changes(Conf.get.clone)
  File.open("../../bot1_conf.yml", 'w') {|f| f.write diff.to_yaml }
rescue
  @error << "Warning: Configuration-File is not writeable!<br>"
end

puts "
<html>
<head>
<meta http-equiv=\"refresh\" content=\"2;url=index.html\">
</head>
<body>
</body>
</html>
"
