require "set"

module LivereloadRails
  class Matchers
    def initialize
      @lookup = {}
      @matchers = []
    end

    def translate(file)
      @matchers.each do |matcher|
        if value = matcher.call(file)
          return value
        end
      end
    end

    def prepend(name, &matcher)
      add(:unshift, name, matcher)
    end

    def append(name, &matcher)
      add(:push, name, matcher)
    end

    def remove(name)
      matcher = @lookup.delete(name) { raise ArgumentError, "matcher #{name} does not exist" }
      @matchers.delete(matcher)
    end

    private

    def add(method, name, matcher)
      raise ArgumentError, "no matcher given" unless matcher
      raise ArgumentError, "matcher #{matcher} already exists" if @lookup.has_key?(name)

      @lookup[name] = matcher
      @matchers.public_send(method, matcher)
      matcher
    end
  end
end
