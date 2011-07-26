require "rubygems"
require "filewatch/tailglob"
require "eventmachine"
require "logstash-lite/namespace"

#Wrapper to include a type with each TailGlob
class LogStashLite::Glob < FileWatch::TailGlob
  attr_accessor :type
end
