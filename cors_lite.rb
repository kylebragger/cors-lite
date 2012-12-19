# Heavily inspired by https://github.com/leehambley/rack-thumb-proxy

require 'open-uri'

module Rack
  class ImageProxy
    
    class << self
      def call(env)
        new(env).call
      end
    end
    
    def initialize(env)
      @env = env
      @path = env['PATH_INFO']
    end
    
    def call
      parse_request!
      
      response = Rack::Response.new
      
      unless @_request_match_data && @_request_match_data.names.include?('escaped_url')
        response.status = 404
        response.headers['Content-Type'] = 'text/plain'
        response.headers['Content-Length'] = 9.to_s
        response.body << 'Not Found'
      else
        load_upstream_image_file! # TODO Handle 404 from upstream image

        response.status = 200
        response.headers['Content-Type'] = content_type_from_file
        response.headers['Content-Length'] = ::File.size(tempfile.path).to_s
        response.body << read_tempfile
        
      end
      
      response.finish
    end
    
    private
    
    def parse_request!
      @_request_match_data = @path.match(routing_pattern)
    end
    
    def routing_pattern
      # TODO This is okay for now, but we'll need to further protect
      # against non-Moonbase images being proxied
      /\/media\/proxy\/(?<escaped_url>https?.*graph-editor-upload.*)$/
    end
    
    def image_url
      @_image_url ||= CGI.unescape(@_request_match_data[:escaped_url])
    end
    
    def tempfile
      @_tempfile ||= Tempfile.new('rack_image_proxy')
    end
    
    def read_tempfile
      tempfile.rewind
      tempfile.read
    end
    
    def load_upstream_image_file!
      # Open the upstream image file and write it locally
      open(image_url, 'rb') do |f|
        tempfile.binmode
        tempfile.write(f.read)
        tempfile.flush
      end
    end
    
    def content_type_from_file
      {
        '.png'  => 'image/png',
        '.gif'  => 'image/gif',
        '.jpg'  => 'image/jpeg',
        '.jpeg' => 'image/jpeg'
      }.fetch(::File.extname(image_url.sub(/\?.+$/, '')), 'application/octet-stream')
    end
    
  end
end