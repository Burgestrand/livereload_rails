$LOAD_PATH << "./lib"
require "livereload-rails"
require "pry"

require "monitor"
clients = Set.new
clients.extend(MonitorMixin)

run(lambda do |env|
  websocket = Livereload::WebSocket.from_rack(env) do |ws|
    # ws.abort_on_exception = true
    puts "Initializing."

    ws.on(:message) do |frame|
      puts "Data: #{frame}"
      data = frame.data

      if data == "close"
        ws.close
      elsif data == "crash"
        raise "Something bad happened!"
      else
        ws.write(data.upcase)
      end
    end

    ws.on(:open) do
      puts "Open!"
      clients.synchronize { clients.add(ws) }
    end

    ws.on(:close) do
      puts "Close!"
      clients.synchronize { clients.delete(ws) }
    end
  end

  if websocket
    [-1, {}, []]
  else
    [200, { "Content-type" => "text/html" }, [File.read("index.html")]]
  end
end)

__END__
<!DOCTYPE html>
<html>
  <head>
  </head>
  <body>
    <script>
      var ws = new WebSocket("ws://localhost:5000/");
      ws.addEventListener("open", function() {
        console.log("open!");
      });
      ws.addEventListener("close", function() {
        console.log("close!");
      });
      ws.addEventListener("error", function(error) {
        console.error("error!", error);
      });
      ws.addEventListener("message", function(message) {
        console.log("message!", message);
      });
    </script>
  </body>
</html>
