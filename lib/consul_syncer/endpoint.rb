# frozen_string_literal: true
class ConsulSyncer
  class Endpoint
    def initialize(service_hash)
      @hash = service_hash
    end

    def name
      @hash.fetch('Service').fetch('Service')
    end

    def service_id
      @hash.fetch('Service').fetch('ID')
    end

    def service_address
      @hash.fetch('Service').fetch('Address')
    end

    def node
      @hash.fetch('Node').fetch('Node')
    end

    def port
      @hash.fetch('Service').fetch('Port')
    end

    def tags
      @hash.fetch('Service').fetch('Tags', [])
    end

    def ip
      @hash.fetch('Node').fetch('Address')
    end
  end
end
