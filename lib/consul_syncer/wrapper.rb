# frozen_string_literal: true
# - parses json responses
# - fails with descriptive output when a request fails

require 'json'

class ConsulSyncer
  class Wrapper
    BACKOFF = [0.1, 0.5, 1.0, 2.0].freeze

    class ConsulError < StandardError
    end

    def initialize(consul, params:, logger:)
      @consul = consul
      @params = params
      @logger = logger
    end

    def request(method, path, payload = nil)
      if @params.any?
        separator = (path.include?("?") ? "&" : "?")
        path += "#{separator}#{URI.encode_www_form(@params)}"
      end
      args = [path]
      args << payload.to_json if payload

      retry_on_error do
        response = @consul.send(method, *args)
        if response.status == 200
          if method == :get
            JSON.parse(response.body)
          else
            true
          end
        else
          raise(
            ConsulError,
            "Failed to request #{response.env.method} #{response.env.url}: #{response.status} -- #{response.body}"
          )
        end
      end
    end

    private

    def retry_on_error
      yield
    rescue Faraday::Error, ConsulError
      retried ||= 0
      backoff = BACKOFF[retried]
      raise unless backoff
      retried += 1

      @logger.warn "Consul request failed, retrying in #{backoff}s"
      sleep backoff
      retry
    end
  end
end
