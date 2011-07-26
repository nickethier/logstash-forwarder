require "logstash-forwarder/namespace"

# Global config registry.
module LogStashForwarder::Config::Registry
  @registry = Hash.new
  class << self
    attr_accessor :registry

    # TODO(sissel): Add some helper methods here.
  end
end # module LogStashForwarder::Config::Registry
  
