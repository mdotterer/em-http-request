#--
# Copyright (C)2008 Ilya Grigorik
# You can redistribute this under the terms of the Ruby license
# See file LICENSE for details
#++

require 'eventmachine'
require 'escape_utils'
require 'addressable/uri'
require 'http/parser'

require 'base64'
require 'socket'

require 'lib/em-http/core_ext/bytesize'
require 'lib/em-http/http_header'
require 'lib/em-http/http_encoding'
require 'lib/em-http/http_options'
require 'lib/em-http/client'
require 'lib/em-http/multi'
require 'lib/em-http/request'
require 'lib/em-http/decoders'
require 'lib/em-http/mock'


module EventMachine
  HttpClientParserError = HTTP::Parser::Error

  class HttpClientParser
    def initialize
      @parser = HTTP::Parser.new
      @finished = false
      @errored = false
      @nread = 0
    end

    def execute(env, data, nparsed)
      data = nparsed == 0 ? data : data[nparsed..-1]

      # mongrel client parser also parses chunk headers
      if env.respond_to?(:http_chunk_size=)
        if data =~ /^([\da-f]+)\r\n/
          env.http_chunk_size = $1
          bytes = $1.size + 2

          @finished = true
          @nread += bytes
        end

      else
        @parser.on_headers_complete = proc{ |headers|
          @finished = true

          headers.each do |key, val|
            env[key.upcase.gsub('-','_')] = val
          end

          env.http_version = @parser.http_version.join('.')
          env.http_status  = @parser.status_code.to_s
          env.http_reason  = 'unknown'

          :stop
        }

        begin
          bytes = @parser << data
        rescue HTTP::Parser::Error => e
          @errored = true
          raise e
        end

        @nread += bytes
      end

      nread
    end

    def finish
      @finished = true
    end

    def finished?
      @finished
    end

    def error?
      @errored
    end

    def nread
      @nread
    end

    def reset
      initialize
    end
  end
end

module EventMachine
  class Buffer < String
    def initialize(size=nil)
      super()
    end
    def clear
      replace('')
    end
    def append(str)
      self << str
    end
    def prepend(str)
      replace("#{str}#{self}")
    end
    def read(len = nil)
      slice!(0, len||size)
    end
    def read_from(io)
      raise NotImplementedError
    end
    def write_to(io)
      raise NotImplementedError
    end
  end
end
