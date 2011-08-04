require "rubygems"
require "amqp"
require "eventmachine"
require "json"
require "filewatch/tailglob"
require "socket"
require "logstash-forwarder/namespace"
require "logstash-forwarder/glob"
require "logstash-forwarder/event"
require "logstash-forwarder/logging"
require "logstash-forwarder/config/file"
require "optparse"



class LogStashForwarder::Agent
  attr_reader :config
  attr_reader :daemonize #Not used yet

  
  #flags
  attr_reader :logfile #Not used yet
  attr_reader :verbose #Not used yet


  public
  def initialize(args)
    @config = { "tail" => [] }
    @amqp = {
      "durable" => true,
      "exchange_type" => nil,
      "host" => nil,
      "name" => nil,
      "password" => "guest",
      "persistent" => true,
      "port" => 5672,
      "user" => "guest",
      "vhost" => "/",
      "key" => ""
    }
    @logger = LogStashForwarder::Logger.new(STDERR)
    @verbose = 0
    @opts = OptionParser.new
    options(@opts)
    @opts.parse(args)
    configure
    if @config_path
      config = LogStashForwarder::Config::File.new(nil, File.new(@config_path).read)
    else # @config_string
      # Given a config string by the user (via the '-e' flag)
      config = LogStashForwarder::Config::File.new(nil, @config_string)
    end
      
    config.parse do |conf|
      if conf[:type] == "input"
        if conf[:plugin] == "file"
          @config["tail"] << { "type" => conf[:parameters]["type"].first, "files" => conf[:parameters]["path"] }
        else
          @logger.warn "Ignoring input #{conf[:plugin]}... Only file type inputs are supported."
        end
      elsif conf[:type] == "filter"
        @logger.warn "Ignoring filter #{conf[:plugin]}... This is suppose to be lightweight dammit!"
      elsif
        if conf[:plugin] == "amqp"
          @amqp[:durable] = boolean(conf[:parameters]["durable"].first)
          @amqp[:exchange_type] = conf[:parameters]["exchange_type"].first
          @amqp[:host] = conf[:parameters]["host"].first
          @amqp[:name] = conf[:parameters]["name"].first
          @amqp[:password] = conf[:parameters]["password"].first
          @amqp[:persistent] = boolean(conf[:parameters]["persistent"].first)
          @amqp[:port] = conf[:parameters]["port"].first
          @amqp[:user] = conf[:parameters]["user"].first
          @amqp[:vhost] = conf[:parameters]["vhost"].first
          @amqp[:key] = conf[:parameters]["key"].first
            
        else
          @logger.warn "Ignoring output #{conf[:plugin]}... Only amqp type outputs are supported."
        end
      end
    end
    @nodename = Socket.gethostname
  end
 
  def run
    EventMachine.run do
      @logger.info "Connecting to #{@amqp[:user]}@#{@amqp[:host]}:#{@amqp[:port]}"
      connection = AMQP.connect(:host     => @amqp[:host], 
                                :port     => @amqp[:port],
                                :vhost    => @amqp[:vhost],
                                :username => @amqp[:user],
                                :password => @amqp[:password])

      channel = AMQP::Channel.new(connection)
      exchange = nil
      @logger.debug "Creating #{@amqp[:exchange_type]} exchange \"#{@amqp[:name]}\" with durability set to #{@amqp[:durable]}."
      if @amqp[:exchange_type] == "fanout"
        exchange = channel.fanout(@amqp[:name], :durable => @amqp[:durable])
      elsif @amqp[:exchange_type] == "direct"
        exchange = channel.direct(@amqp[:name], :durable => @amqp[:durable])
      elsif @amqp[:exchange_type] == "topic"
        exchange = channel.topic(@amqp[:name], :durable => @amqp[:durable])
      else
        @logger.fatal "Exchange type must be fanout, topic or direct!"
      end
      
      @config["tail"].each do |glob|
        tail = LogStashForwarder::Glob.new
        tail.logger = @logger
        tail.type = glob["type"]
        glob["files"].each do |file|
          tail.tail(file)
        end #glob["files"].each
        tail.subscribe do |path, data|
          event = LogStashForwarder::Event.new({"@type" => tail.type, "@message"=>data})
	  event.source = "file://#{@nodename}#{path}"
          exchange.publish(event.to_json, :routing_key => event.sprintf(@amqp[:key]), :persistent => @amqp[:persistent])
          @logger.debug(["Sending event", { :destination => to_s, :event => event, :key => event.sprintf(@amqp[:key])}])
        end #subscribe
      end #config["tail"].each
    end #end EventMachine
  end #end run method
  
  def to_s
    return "#{@amqp[:user]}@#{@amqp[:host]}:#{@amqp[:port]}/#{@amqp[:exchange_type]}/#{@amqp[:name]}"
  end
  
  def options(opts)
    
    opts.on("-f CONFIGPATH", "--config CONFIGPATH", 
            "Load the logstash-forwarder config from a specific file.") do |arg|
      @config_path = arg
    end # -f / --config

    opts.on("-e CONFIGSTRING",
            "Use the given string as the configuration data. Same syntax as " \
            "the config file. If no input is specified, " \
            "'stdin { type => stdin }' is default. If no output is " \
            "specified, 'stdout { debug => true }}' is default.") do |arg|
      @config_string = arg
    end # -e

    opts.on("-d", "--daemonize", "Daemonize (default is run in foreground)") do 
      @daemonize = true
    end

    opts.on("-l", "--log FILE", "Log to a given path. Default is stdout.") do |path|
      @logfile = path
    end

    opts.on("-v", "Increase verbosity") do
      @verbose += 1
    end

  end # def options

  def configure
    if @config_path && @config_string
      @logger.fatal "Can't use -f and -e at the same time"
      raise "Configuration problem"
    elsif (@config_path.nil? || @config_path.empty?) && @config_string.nil?
      @logger.fatal "No config file given. (missing -f or --config flag?)"
      @logger.fatal @opts.help
      raise "Configuration problem"
    end

    #if @config_path and !File.exist?(@config_path)
    if @config_path and Dir.glob(@config_path).length == 0
      @logger.fatal "Config file '#{@config_path}' does not exist."
      raise "Configuration problem"
    end

    if @logfile
      logfile = File.open(@logfile, "w")
      STDOUT.reopen(logfile)
      STDERR.reopen(logfile)
    elsif @daemonize
      devnull = File.open("/dev/null", "w")
      STDOUT.reopen(devnull)
      STDERR.reopen(devnull)
    end

    if @verbose >= 3  # Uber debugging.
      @logger.level = Logger::DEBUG
    elsif @verbose == 2 # logstash debug logs
      @logger.level = Logger::DEBUG
    elsif @verbose == 1 # logstash info logs
      @logger.level = Logger::INFO
    else # Default log level
      @logger.level = Logger::WARN
    end
  end # def configure

  def boolean(string)
    return true if string== true || string =~ (/(true|t|yes|y|1)$/i)
    return false if string== false || string.nil? || string =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{string}\"")
  end
end #end class
      
     

