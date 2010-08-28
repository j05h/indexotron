require 'rubygems'
require 'net/http'
require 'uri'
require 'nokogiri'
require 'json'
require 'elasticsearch'

class Crawler
  class NoUrlSpecified < StandardError; end

  def self.start_crawling(options={})
    crawler = new(options)
    crawler.start_crawler
    crawler.start_fetchers
  end

  def initialize(options={})
    @url           = options[:url]
    @max_depth     = options[:depth] || 1
    @mutex         = Mutex.new
    @queue         = []
    @fetcher_count = 3

    raise NoUrlSpecified unless @url
    # puts "We're going to crawl: #{@url} with a max depth of #{@max_depth}"
  end

  def queue
    @mutex.synchronize do
      @queue
    end
  end

  def start_crawler
    queue.push([@url, 0])
  end

  def start_fetchers
    @fetcher_threads ||= @fetcher_count.times.map do
      Thread.new do
        loop do
          if item = queue.shift
            crawl(*item)
          end

          next unless queue.empty?
          sleep 0.5
        end
      end
    end
    @fetcher_threads.each{|t| t.join}
  end

  def crawl(url, depth = 0)
    begin
      response = fetch(url)
    rescue Exception
      log("FAILED: #{url}", depth)
    end
    return unless response

    page = Nokogiri::HTML(response.body)
    index url, response, page
    return true if depth+1 > @max_depth

    page.css('a').each do |link|
      new_url = link['href']
      next unless valid_url?(new_url)
      queue.push([new_url, depth+1])
    end
  end

  def indexer
    return @indexer if @indexer
    host = URI.parse(@url).host
    @indxer = ElasticSearch.new('127.0.0.1:9200', :index => host, :type => "docs")
  end

  def search query
    indexer.search query
  end

  def get guid
    indexer.get guid
  end

  def self.search site, query
    Crawler.new(:url => site).search query
  end

  def self.get site, guid
    Crawler.new(:url => site).get guid
  end

  def index url, response, page
    hash = {
      'url'   => url,
      'title' => page.css('title').first.content,
      # we need to parse out valuable text here leave JS on the floor
      'body'  => page.css('body').first.inner_text,
      'page'  => response.body
    }
    response.each_header{ |k,v| hash[k] = v }
    indexer.index(hash)
    log("INDEXED: #{url} - #{hash['title']}")
  end

  def fetch(uri_str, limit = 10)
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0

    case response = Net::HTTP.get_response(URI.parse(uri_str))
    when Net::HTTPSuccess     then response
    when Net::HTTPRedirection then fetch(response['location'], limit - 1)
    else
      response.error!
    end
  end

  def log(message, depth=0)
    puts "#{"\t"*depth}#{Thread.current.object_id} - #{message}"
  end

  def valid_url?(url)
    return false if url.nil? || url =~ /^#/ || url =~ /^javascript/
    begin
      URI.parse(url)
      true
    rescue URI::InvalidURIError
      false
    end
  end
end

if __FILE__ == $0
  Crawler.start_crawling :url => ARGV[0], :depth => 2
end

