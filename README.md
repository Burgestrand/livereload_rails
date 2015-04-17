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

## Contributing

1. Fork it ( https://github.com/[my-github-username]/rails-livereload/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
