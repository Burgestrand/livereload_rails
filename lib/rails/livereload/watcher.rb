module Livereload
  class Watcher
    class << self
      attr_reader :instance

      def start(*args)
        raise "Already initialized." if @instance
        Thread.new do
          @instance = new(*args)
          @instance.run
        end
      end
    end

    def initialize(sprockets)
      @sprockets = sprockets
      @watcher = FileWatcher.new(@sprockets.paths, true)
      @observers = WeakObservable.new
    end

    def run
      @watcher.watch(0.2) do |file, event|
        asset = @sprockets.find_asset(file)
        @observers.notify(asset, event)
      end
    end

    delegate :add, to: :@observers
  end
end
