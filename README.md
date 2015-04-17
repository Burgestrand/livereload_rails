# Livereload::Rails

## Installation

```ruby
gem "livereload-rails", group: :development
```

That's it. Your CSS now livereloads. A few notes that could be of interest:

- requires a threaded webserver, so puma is a runtime dependency for ease of installation.
- adds middleware `Rack:LiveReload` which automatically includes `livereload.js`
- adds middleware `Livereload::Middleware` which acts as websocket/livereload server

## Development

If you wish to contribute to this gem, here are some notes I hope will help you:

- `bin/setup`: run to install development dependencies.
- `bin/console`: run to start an interactive console to experiment with the code.
- `rake`: run the automated test suite.

### Implementation Notes

Livereload::Rails consists of the following parts:

- [Watcher](./lib/livereload-rails/watcher.rb) - responsible for watching the asset paths for file changes.
- [WebSocket](./lib/livereload-rails/web_socket.rb) - websocket server handler for rack.
- [Client](./lib/livereload-rails/client.rb) - livereload server handler.
- [Middleware](./lib/livereload-rails/middleware.rb) - rack middleware to accept websocket connections.
- [Railtie](./lib/livereload-rails/railtie.rb) - rails engine to automatically hook rails up with livereload.

### Contributing

Contributions are very welcome! Follow these steps:

1. [Fork the code](https://github.com/Burgestrand/livereload-rails/fork): https://help.github.com/articles/fork-a-repo/
2. Create a new pull request with your changes: https://help.github.com/articles/using-pull-requests/

It's perfectly fine to create a pull request with your code and continue a discussion from your changes from there.
