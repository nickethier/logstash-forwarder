require "rubygems"
require "filewatch/tailglob"
require "eventmachine"
require "logstash-forwarder/namespace"

#Wrapper to include a type with each TailGlob
class LogStashForwarder::Glob < FileWatch::TailGlob
  attr_accessor :type
end
