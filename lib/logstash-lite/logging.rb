require "logstash-lite/namespace"
require "logger"

class LogStashLite::Logger < Logger
  # Try to load awesome_print, if it fails, log it later
  # but otherwise we will continue to operate as normal.
  begin 
    require "ap"
    @@have_awesome_print = true
  rescue LoadError => e
    @@have_awesome_print = false
    @@notify_awesome_print_load_failed = e
  end

  public
  def initialize(*args)
    super(*args)
    @formatter = LogStashLite::Logger::Formatter.new

    # Set default loglevel to WARN unless $DEBUG is set (run with 'ruby -d')
    self.level = $DEBUG ? Logger::DEBUG: Logger::INFO
    if ENV["LOGSTASH_DEBUG"]
      self.level = Logger::DEBUG
    end

    @formatter.progname = self.progname = File.basename($0)

    # Conditional support for awesome_print
    if !@@have_awesome_print && @@notify_awesome_print_load_failed
      debug [ "awesome_print not found, falling back to Object#inspect." \
              "If you want prettier log output, run 'gem install "\
              "awesome_print'", 
              { :exception => @@notify_awesome_print_load_failed }]

      # Only show this once.
      @@notify_awesome_print_load_failed = nil
    end
  end # def initialize

  public
  def level=(level)
    super(level)
    @formatter.level = level
  end # def level=
end # class LogStash::Logger

# Implement a custom Logger::Formatter that uses awesome_inspect on non-strings.
class LogStashLite::Logger::Formatter < Logger::Formatter
  attr_accessor :level
  attr_accessor :progname

  public
  def call(severity, timestamp, who, object)
    # override progname to be the caller if the log level threshold is DEBUG
    # We only do this if the logger level is DEBUG because inspecting the
    # stack and doing extra string manipulation can have performance impacts
    # under high logging rates.
    if @level == Logger::DEBUG
      # callstack inspection, include our caller
      # turn this: "/usr/lib/ruby/1.8/irb/workspace.rb:52:in `irb_binding'"
      # into this: ["/usr/lib/ruby/1.8/irb/workspace.rb", "52", "irb_binding"]
      #
      # caller[3] is actually who invoked the Logger#<type>
      # This only works if you use the severity methods
      path, line, method = caller[3].split(/(?::in `|:|')/)
      # Trim RUBYLIB path from 'file' if we can
      #whence = $:.select { |p| path.start_with?(p) }[0]
      whence = $:.detect { |p| path.start_with?(p) }
      if !whence
        # We get here if the path is not in $:
        file = path
      else
        file = path[whence.length + 1..-1]
      end
      who = "#{file}:#{line}##{method}"
    end

    # Log like normal if we got a string.
    if object.is_a?(String)
      super(severity, timestamp, who, object)
    else
      # If we logged an object, use .awesome_inspect (or just .inspect)
      # to stringify it for higher sanity logging.
      if object.respond_to?(:awesome_inspect)
        super(severity, timestamp, who, object.awesome_inspect)
      else
        super(severity, timestamp, who, object.inspect)
      end
    end
  end # def call
end # class LogStash::Logger::Formatter