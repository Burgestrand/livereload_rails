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
        unless FileTest.file?(path)
          LivereloadRails.logger.debug "#{path} -> not a file."
          next
        end

        unless filename = translate(path)
          LivereloadRails.logger.debug "#{path} -> no match."
          next
        end

        if filename.empty?
          LivereloadRails.logger.debug "#{path} -> ignored."
          next
        end

        LivereloadRails.logger.debug "#{path} -> #{filename}."
        @update[filename]
      end
    end

    def translate(path)
      @matchers.find do |name, matcher|
        if value = matcher.call(path)
          return value
        end
      end
    end
  end
end
