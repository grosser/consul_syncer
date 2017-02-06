# frozen_string_literal: true
require_relative 'test_helper'

SingleCov.covered!

describe ConsulSyncer do
  let(:syncer) { ConsulSyncer.new("http://localhost:123", logger: Logger.new("/dev/null")) }

  it "complains when not passing any tags" do
    assert_raises ArgumentError do
      syncer.sync([], [])
    end
  end

  it "does nothing when everything is empty" do
    stub_request(:get, "http://localhost:123/v1/catalog/services?tag=foo").
      to_return(body: "[]")
    syncer.sync([], ['foo', 'bar'])
  end

  describe "with services running" do
    let(:tags) { ["bar", "baz"] }
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

    before do
      stub_request(:get, "http://localhost:123/v1/catalog/services?tag=bar").
        to_return(body: {foo: tags}.to_json)
      stub_request(:get, "http://localhost:123/v1/health/service/foo").
        to_return(body: [node].to_json)
    end

    it "does nothing when in sync" do
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

    it "updates modified service" do
      stub_request(:put, "http://localhost:123/v1/catalog/register").
        with(body: {"{\"Node\":\"foo.test.com\",\"Address\":\"10.0.1.1\",\"Service\":{\"ID\":\"fooid\",\"Service\":\"foo\",\"Address\":\"10.0.2.2\",\"Tags\":\"bar\",\"baz\",\"Port\":5081}}"=>nil})
      definition[:port] += 1
      syncer.sync [definition], tags.first(1)
    end
  end
end
