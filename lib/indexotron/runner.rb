require 'fileutils'
require 'optparse'
require File.join(File.dirname(__FILE__), 'crawler')

module Indexotron
  class Runner
    NDXO_DIR   = File.expand_path(ENV['NDXO_DIR'] || "~/indexotron/")
    ES_VERSION = "elasticsearch-0.10.0"
    class << self
      def run
        options = configure
        execute options
      end

      def execute options
        case(options[:command])
        when /^install$/
          install
        when /^start$/
          start
        when /^stop$/
          stop
        when /^pid$/
          puts pid
        when /^index/
          index options[:site], option[:argument] || 1
        when /^search/
          search options[:site], options[:argument]
        when /^open/
          open options[:site], options[:argument]
        else
          help
        end
      end

      def configure
        options = {:site => ENV['NDXO_SITE']}
        OptionParser.new do |opts|
          opts.banner = help

          opts.on("-s", "--site [SITE]", String, "Site to host") do |site|
            options[:site] = site
          end

          opts.on_tail '-h', '--help','Show this message' do
            puts opts
          end
        end.parse!

        options[:command]  = ARGV.shift
        options[:argument] = ARGV.shift
        options
      end

      def index url, depth = 1
        Crawler.start_crawling :url => url, :depth => depth
      end

      def search site, query
        puts Crawler.search( site, query ).map{ |x| "[#{x.id}]: #{x.title}" }
      end

      def open site, guid
        # write to tmp file
        object = Crawler.get site, guid
        filename = "/tmp/#{guid}.html"
        File.open filename, 'w+' do |file|
          file.write object.page
        end
        `open #{filename}`
      end

      def install
        FileUtils.mkdir_p(NDXO_DIR)
        location = File.join NDXO_DIR, "#{ES_VERSION}.zip"
        download "http://github.com/downloads/elasticsearch/elasticsearch/#{ES_VERSION}.zip", location
        sys "cd #{NDXO_DIR} && unzip #{location}"
      end

      def start
        location = File.join NDXO_DIR, ES_VERSION
        if File.exists? location
          sys "cd #{location} && bin/elasticsearch > output 2>&1"
          puts "Started elastic search (#{pid})"
        else
          puts "elastic search does not exist at #{location}.  Try 'ndxo install' first."
        end
      end

      def pid
        @pid ||= `ps -ef | grep [e]lastic | awk '{print $2}'`.split("\n").join(" ")
      end

      def stop
        if pid.empty?
          puts "No elastic search is started"
        else
          puts "Stopping elastic search (#{pid})"
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
        <<-MSG
Indexotron is a gem to help index and search web site.
-------------------------------------------------------
ndxo <command> [options]
Commands: 
  * install: installs to NDXO_DIR or ~/indexotron (elasticsearch.com)
  * start  : starts an elastic search instance
  * stop   : stops all elastic search instances
  * search : searches the index and outputs the results
  * open   : opens the given guid (get from a search) in a browser (MacOS X only)
  * pid:   : prints pids for all instances
  * help   : prints this help

  Options:
MSG
      end
    end
  end
end
