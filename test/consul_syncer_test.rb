# frozen_string_literal: true
require_relative 'test_helper'

SingleCov.covered!

describe ConsulSyncer do
  let(:syncer) { ConsulSyncer.new("http://localhost:123", logger: Logger.new("/dev/null")) }
  let(:tags) { ["bar", "baz"] }
  let(:definition) do
    {
      node: 'foo.test.com',
      address: '10.0.1.1',
      service: 'foo',
      service_id: 'fooid',
      service_address: '10.0.2.2',
      tags: tags.last(1),
      port: 5080
    }
  end

  it "complains when not passing any tags" do
    assert_raises ArgumentError do
      syncer.sync([], [])
    end
  end

  it "does nothing when everything is empty" do
    stub_request(:get, "http://localhost:123/v1/catalog/services?cached&stale&tag=foo").
      to_return(body: "[]")
    syncer.sync([], ['foo', 'bar'])
  end

  describe "with services running" do
    let(:node) do
      {
        Node: {
          Node: "foo.test.com",
          Address: "10.0.1.1",
        },
        Service: {
          ID: "fooid",
          Address: "10.0.2.2",
          Service: "foo",
          Tags: tags.dup,
          Port: 5080
        }
      }
    end

    before do
      stub_request(:get, "http://localhost:123/v1/catalog/services?cached&stale&tag=bar").
        to_return(body: {foo: tags}.to_json)
      stub_request(:get, "http://localhost:123/v1/health/service/foo").
        to_return(body: [node].to_json)
    end

    it "does nothing when in sync" do
      syncer.sync [definition], tags.first(1)
    end

    it "does not modify services that are marked as keep when they are found" do
      definition[:port] += 1 # would normally trigger an update
      definition[:keep] = true
      syncer.sync [definition], tags.first(1)
    end

    it "does not modify nodes that are marked as keep when they are found" do
      definition.delete(:service_id)
      definition.delete(:service)
      definition[:keep] = true
      syncer.sync [definition], tags.first(1)
    end

    it "does not add new services when marked as keep is not found" do
      definition[:node] += "foo" # would be a new service
      definition[:keep] = true
      stub_request(:put, "http://localhost:123/v1/catalog/deregister")
      syncer.sync [definition], tags.first(1)
    end

    it "adds a missing service" do
      stub_request(:put, "http://localhost:123/v1/catalog/register").
        with(body: {"{\"Node\":\"foo.test.com\",\"Address\":\"1.2.3.4\",\"Service\":{\"ID\":\"fooid\",\"Service\":\"foo\",\"Address\":\"10.0.2.2\",\"Tags\":\"bar\",\"baz\",\"Port\":5080}}"=>nil})

      other = definition.dup
      other[:address] = '1.2.3.4'
      syncer.sync [definition, other], tags.first(1)
    end

    it "removes extra service" do
      stub_request(:put, "http://localhost:123/v1/catalog/deregister").
        with(body: {"{\"Node\":\"foo.test.com\",\"ServiceID\":\"fooid\"}"=>nil})
      syncer.sync [], tags.first(1)
    end

    it "does not match services that fail multi-tag match" do
      stub_request(:put, "http://localhost:123/v1/catalog/register") # not matched -> new service
      syncer.sync [definition], tags + ["nope"]
    end

    it "does not match endpoints with missing tags" do
      node[:Service][:Tags].pop
      stub_request(:get, "http://localhost:123/v1/health/service/foo").
        to_return(body: [node].to_json)
      stub_request(:put, "http://localhost:123/v1/catalog/register") # not matched -> new service
      syncer.sync [definition], tags
    end

    it "updates modified service" do
      stub_request(:put, "http://localhost:123/v1/catalog/register").
        with(body: {"{\"Node\":\"foo.test.com\",\"Address\":\"10.0.1.1\",\"Service\":{\"ID\":\"fooid\",\"Service\":\"foo\",\"Address\":\"10.0.2.2\",\"Tags\":\"bar\",\"baz\",\"Port\":5081}}"=>nil})
      definition[:port] += 1
      syncer.sync [definition], tags.first(1)
    end

    describe "dry" do
      it "does not remove" do
        other = definition.dup
        other[:address] = '1.2.3.4'
        syncer.sync [definition, other], tags.first(1), dry: true
      end

      it "does not add" do
        syncer.sync [], tags.first(1), dry: true
      end

      it "does not update" do
        definition[:port] += 1
        syncer.sync [definition], tags.first(1), dry: true
      end
    end
  end

  describe "with extra_params" do
    let(:syncer) { ConsulSyncer.new("http://localhost:123", logger: Logger.new("/dev/null"), params: {from_host: 'xyz', foo: 'bar'}) }

    it "sends params during requests" do
      stub_request(:get, "http://localhost:123/v1/catalog/services?cached&stale&foo=bar&from_host=xyz&tag=some-tag").to_return(body: "[]")
      stub_request(:put, "http://localhost:123/v1/catalog/register?foo=bar&from_host=xyz")
      syncer.sync [definition], ["some-tag"]
    end
  end
end
