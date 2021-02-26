# frozen_string_literal: true
require 'faraday'
require 'logger'
require 'consul_syncer/endpoint'
require 'consul_syncer/wrapper'

# syncs a given list of endpoints into consul
# - sorts tags
# - adds missing
# - updates changed
# - removes deprecated
class ConsulSyncer
  def initialize(url, logger: Logger.new(STDOUT), params: {})
    @logger = logger
    @consul = Wrapper.new(url, params: params, logger: @logger)
  end

  # changing tags means all previous services need to be removed manually since
  # they can no longer be found
  def sync(expected_definitions, tags)
    raise ArgumentError, "Need at least 1 tag to reliably update endpoints" if tags.empty?

    modified = 0

    # ensure consistent tags to find the endpoints after adding
    expected_definitions = expected_definitions.dup
    expected_definitions.each do |d|
      d[:tags] += tags
      d[:tags].sort!
      d[:tags].uniq!
    end

    actual_definitions = consul_endpoints(tags).map do |consul_endpoint|
      {
        node: consul_endpoint.node,
        address: consul_endpoint.ip,
        service: consul_endpoint.name,
        service_id: consul_endpoint.service_id,
        service_address: consul_endpoint.service_address,
        tags: consul_endpoint.tags.sort,
        port: consul_endpoint.port
      }
    end

    identifying = [:node, :service_id]
    interesting = [*identifying, :service, :service_address, :address, :tags, :port]

    expected_definitions.each do |expected|
      description = "#{expected[:service] || "*"} / #{expected[:service_id] || "*"} on #{expected.fetch(:node)} in Consul"

      if expected[:keep]
        keep_identifying = identifying.dup
        keep_identifying.delete(:service_id) unless expected[:service_id]
        if remove_matching_service!(actual_definitions, expected, keep_identifying)
          @logger.warn "Kept #{description}"
        else
          @logger.error "Unable to keep #{description} since it was not found"
        end
      elsif remove_matching_service!(actual_definitions, expected, interesting)
        @logger.debug "Found #{description}"
      elsif remove_matching_service!(actual_definitions, expected, identifying)
        @logger.info "Updating #{description}"
        modified += 1
        register **expected
      else
        @logger.info "Adding #{description}"
        modified += 1
        register **expected
      end
    end

    # all definitions that are left did not match any expected definitions and are no longer needed
    actual_definitions.each do |actual|
      @logger.info "Removing #{actual.fetch(:service)} / #{actual.fetch(:service_id)} on #{actual.fetch(:node)} in Consul"
      modified += 1
      deregister actual.fetch(:node), actual.fetch(:service_id)
    end

    modified
  end

  private

  def consul_endpoints(requested_tags)
    services = @consul.request(:get, "/v1/catalog/services?cached&stale&tag=#{requested_tags.first}")
    services.each_with_object([]) do |(name, tags), all|
      # cannot query for multiple tags via query, so handle multi-matching manually
      next if (requested_tags - tags).any?

      @logger.debug "Getting service endpoints for #{name}"
      # this also finds the 'external services' we define since they have no checks
      endpoints = @consul.request(:get, "/v1/health/service/#{name}")
      endpoints.each do |endpoint|
        endpoint = Endpoint.new(endpoint)
        next if (requested_tags - endpoint.tags).any?
        all << endpoint
      end
    end
  end

  def remove_matching_service!(actuals, expected, keys)
    return unless found = actuals.detect { |actual| actual.values_at(*keys) == expected.values_at(*keys) }
    actuals.delete(found)
  end

  # creates or updates based on node and service
  def register(node:, service:, service_id:, service_address:, address:, tags:, port:)
    @consul.request(
      :put,
      '/v1/catalog/register',
      Node: node,
      Address: address,
      Service: {
        ID: service_id,
        Service: service,
        Address: service_address,
        Tags: tags,
        Port: port
      }
    )
  end

  def deregister(node, service_id)
    @consul.request(
      :put,
      '/v1/catalog/deregister',
      Node: node,
      ServiceID: service_id
    )
  end
end
