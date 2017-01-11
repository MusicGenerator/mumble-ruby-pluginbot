require 'socket'



@s = TCPSocket.new 'localhost', 7750
@s.puts "userhashes"
users= @s.gets
@s.close
puts users
