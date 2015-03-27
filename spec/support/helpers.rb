module Helpers
  def handshake_env(*args)
    env = {}

    client_handshake = WebSocket::Handshake::Client.new(*args)
    server_handshake = WebSocket::Handshake::Server.new(secure: false)
    server_handshake << client_handshake.to_s

    server_handshake.headers.each do |key, value|
      env["HTTP_#{key.gsub("-", "_").upcase}"] = value
    end
    env["REQUEST_PATH"] = server_handshake.path
    env["QUERY_STRING"] = server_handshake.query

    env
  end

  def ws_frame(data, type: :text)
    ::WebSocket::Frame::Outgoing::Server.new(data: data, type: type).to_s
  end
end
