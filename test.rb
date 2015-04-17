require "socket"

server = TCPServer.new("localhost", 0)

local = TCPSocket.new("localhost", server.addr(true)[1])
remote = server.accept

local_a = local
local_b = local.dup

remote.close

p local_b.write "\x0"
p local_a.write "\x0"

puts "#1"
p local_a.closed? # YES
puts "#2"
p local_b.closed? # NO
puts "#3"
