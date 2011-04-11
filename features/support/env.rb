$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../../lib")
require 'rubygems'
require 'mirage'
require 'cucumber'
require 'rspec'
require 'mechanize'
require 'childprocess'

ENV['RUBYOPT'] =''

include Mirage::Util
SCRATCH = './scratch'
RUBY_CMD = RUBY_PLATFORM == 'JAVA' ? 'jruby' : 'ruby'


BLANK_RUBYOPT_CMD = windows? ? 'set RUBYOPT=' : "export RUBYOPT=''"

if 'regression' == ENV['mode']
  MIRAGE_CMD = windows? ? `where mirage.bat`.chomp : 'mirage'
else
  MIRAGE_CMD = "#{RUBY_CMD} ../bin/mirage"
end

module CommandLine
  COMAND_LINE_OUTPUT_PATH = "#{File.dirname(__FILE__)}/../../#{SCRATCH}/commandline_output.txt"
  module Windows
    def run command
      command = "#{MIRAGE_CMD} #{command.split(' ').drop(1).join(' ')}" if command =~ /^mirage/
      command = "#{command} > #{COMAND_LINE_OUTPUT_PATH}"
      Dir.chdir(SCRATCH)
      `#{BLANK_RUBYOPT_CMD}`
      process = ChildProcess.build(*(command.split(' ')))
      process.start
      sleep 0.5 until process.exited?
      Dir.chdir('../')
      File.read(COMAND_LINE_OUTPUT_PATH)
    end
  end

  module Linux
    def run command
      `#{BLANK_RUBYOPT_CMD} && cd #{SCRATCH} && #{command} > #{File.basename(COMAND_LINE_OUTPUT_PATH)}`
    end
  end
end


module Web
  include Mirage::Web

  def get(url)
    browser = Mechanize.new
    browser.keep_alive= false
    browser.get(url)
  end

  def hit_mirage(url, parameters={})
    start_time = Time.now
    file = parameters.values.find { |value| value.is_a?(File) }
    response = (file ? http_post(url, parameters) : http_get(url, parameters))
    @response_time = Time.now - start_time
    response
  end

  def normalise text
    text.gsub(/[\n]/, ' ').gsub(/\s+/, ' ')
  end
end


module Regression
  include CommandLine

  def run command
    execute(command)
  end
end

module Mirage
  module Runner
    include Mirage::Util

    def stop_mirage
      system "cd #{SCRATCH} && #{MIRAGE_CMD} stop"
    end

    def start_mirage
      if windows?

        puts "starting mirage"
        Dir.chdir(SCRATCH)
        process = ChildProcess.build(MIRAGE_CMD, "start")
        process.start
        sleep 0.5 until process.exited?
        Dir.chdir '../'
        puts "finished starting mirage"
      else
        system "cd #{SCRATCH} && #{MIRAGE_CMD} start"
      end
    end
  end
end


module IntelliJ
  include CommandLine
  include Mirage::Util

  def run command
    execute "#{RUBY_CMD} #{command}"
  end
end

include Mirage::Runner

World(Web)
World(Mirage::Runner)
windows? ? World(CommandLine::Windows) : World(CommandLine::Linux)



Before do
  FileUtils.mkdir_p(SCRATCH)
  $mirage = Mirage::Client.new
  if $mirage.running?
    $mirage.clear
  else
    start_mirage
  end

  Dir["#{SCRATCH}/*"].each do |file|
    FileUtils.rm_rf(file) unless file == "#{SCRATCH}/mirage.log"
  end

  if File.exists? "#{SCRATCH}/mirage.log"
    @mirage_log_file = File.open("#{SCRATCH}/mirage.log")
    @mirage_log_file.seek(0, IO::SEEK_END)
  end
end


at_exit do
  stop_mirage if $mirage.running?
end