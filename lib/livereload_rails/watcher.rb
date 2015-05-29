module LivereloadRails
  class Watcher
    def initialize(paths, matchers:, &update)
      LivereloadRails.logger.debug "Watching #{paths} for changes."
      @watcher = FileWatcher.new(paths)
      @matchers = matchers
      @update = update
    end

    def run(timeout = 0.2)
      @watcher.watch(timeout) do |path, event|
        if filename = translate(path)
          if filename.empty?
            LivereloadRails.logger.debug "#{path} -> ignored."
          else
            LivereloadRails.logger.debug "#{path} -> #{filename}."
            @update[filename]
          end
        else
          LivereloadRails.logger.debug "#{path} -> no match."
        end
      end
    end

    def translate(path)
      @matchers.each do |name, matcher|
        if value = matcher.call(path)
          return value
        end
      end
    end
  end
end
