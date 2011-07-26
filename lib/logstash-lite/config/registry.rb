require "logstash-lite/namespace"

# Global config registry.
module LogStashLite::Config::Registry
  @registry = Hash.new
  class << self
    attr_accessor :registry

    # TODO(sissel): Add some helper methods here.
  end
end # module LogStashLite::Config::Registry
  
