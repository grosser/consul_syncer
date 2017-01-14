# frozen_string_literal: true
require 'faraday'
require 'logger'
require 'consul_syncer/endpoint'
require 'consul_syncer/wrapper'

# syncs a given list of endpoints into consul
# - adds missing
# - updates changed
# - removes deprecated
class ConsulSyncer
  def initialize(url, logger: Logger.new(STDOUT))
    @consul = Wrapper.new(Faraday.new(url))
    @logger = logger
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
    end

    actual_definitions = consul_endpoints(tags).map do |consul_endpoint|
      {
        node: consul_endpoint.node,
        address: consul_endpoint.ip,
        service: consul_endpoint.name,
        service_id: consul_endpoint.service_id,
        tags: consul_endpoint.tags.sort,
        port: consul_endpoint.port
      }
    end

    identifying = [:node, :service]
    interesting = [*identifying, :address, :tags, :port]

    expected_definitions.each do |expected|
      description = "#{expected.fetch(:service)} on #{expected.fetch(:node)} in Consul"

      if remove_matching_service!(actual_definitions, expected, interesting)
        @logger.info "Found #{description}"
      elsif remove_matching_service!(actual_definitions, expected, identifying)
        @logger.info "Updating #{description}"
        modified += 1
        register expected
      else
        @logger.info "Adding #{description}"
        modified += 1
        register expected
      end
    end

    # all definitions that are left did not match any expected definitions and are no longer needed
    actual_definitions.each do |actual|
      @logger.info "Removing #{actual.fetch(:service)} on #{actual.fetch(:node)} in Consul"
      modified += 1
      deregister actual.fetch(:node), actual.fetch(:service_id)
    end

    modified
  end

  private

  def consul_endpoints(requested_tags)
    services = @consul.request(:get, "/v1/catalog/services?tag=#{requested_tags.first}")
    services.each_with_object([]) do |(name, tags), all|
      # cannot query for multiple tags via query, so handle multi-matching manually
      next if (requested_tags - tags).any?

      @logger.info "Getting service endpoints for #{name}"
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
  def register(node:, service:, address:, tags:, port:)
    @consul.request(
      :put,
      '/v1/catalog/register',
      Node: node,
      Address: address,
      Service: {
        Service: service,
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