Gem::Specification.new do |spec|
  files = []
  dirs = %w{lib test}
  dirs.each do |dir|
    files += Dir["#{dir}/**/*"]
  end

  rev = "1" 
  spec.name = "logstash-forwarder"
  spec.version = "0.1.#{rev}"
  spec.summary = "lightweight ruby logstash agent"
  spec.description = "send logs over amqp to logstash"
  spec.license = "Apache License (2.0)"

  spec.add_dependency("eventmachine")
  spec.add_dependency("eventmachine-tail")
  spec.add_dependency("filewatch")
  spec.add_dependency("awesome_print")
  spec.add_dependency("json")
  spec.add_dependency("amqp")


  spec.files = files
  spec.require_paths << "lib"
  spec.bindir = "bin"
  spec.executables << "logstash-forwarder"

  spec.authors = ["Nick Ethier"]
  spec.email = ["ncethier@gmail.com"]
end
