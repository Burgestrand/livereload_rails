module LivereloadRails
  class Watcher
    def initialize(paths, &update)
      LivereloadRails.logger.debug "Watching #{paths} for changes."
      @watcher = FileWatcher.new(paths)
      @update = update
    end

    def run(timeout = 0.2)
      @watcher.watch(timeout, &@update)
    end
  end
end
