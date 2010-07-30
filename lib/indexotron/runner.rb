require 'fileutils'
module Indexotron
  class Runner
    NDXO_DIR = File.expand_path(ENV['NDXO_DIR'] || "~/indexotron/")
    ES_VERSION = "elasticsearch-0.9.0"
    class << self
      def run(command)
        configure
        case(command)
        when /^install$/
          install
        when /^start$/
          start
        when /^stop$/
          stop
        when /^pid$/
          puts pid
        else
          help
        end
      end

      def configure
      end

      def install
        FileUtils.mkdir_p(NDXO_DIR)
        location = File.join NDXO_DIR, "#{ES_VERSION}.zip"
        download "http://github.com/downloads/elasticsearch/elasticsearch/#{ES_VERSION}.zip", location
        sys "cd #{NDXO_DIR} && unzip #{location}"

      end

      def start
        location = File.join NDXO_DIR, ES_VERSION
        sys "cd #{location} && bin/elasticsearch > output 2>&1"
      end

      def pid
        `ps -ef | grep [e]lastic | awk '{print $2}'`.split("\n").join(" ")
      end

      def stop
        if pid.empty?
          puts "No elastic search is started"
        else
          sys "kill -9 #{pid}"
        end
      end

      def download(url, location, force = false)
        sys "curl -L #{url} -o #{location}" if force || !File.exists?(location)
      end

      def sys(command)
        `#{command}`
      end

      def help
        puts <<-MSG
Indexotron is a gem to help index and search web site.
-------------------------------------------------------
ndxo <command>
Commands: 
  * install: installs elastic search (elasticsearch.com)
  * start: starts an elastic search instance
  * stop: stops all elastic search instances
  * pid: prints pids for all instances
  * help: prints this help
MSG
      end
    end
  end
end
