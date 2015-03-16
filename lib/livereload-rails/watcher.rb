module Livereload
  class Watcher
    def initialize(paths, &update)
      @watcher = FileWatcher.new(paths)
      @update = update
    end

    def run(timeout = 0.2)
      @watcher.watch(timeout, &@update)
    end
  end
end
