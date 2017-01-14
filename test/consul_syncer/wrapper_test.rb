# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ConsulSyncer::Wrapper do
  let(:consul) { ConsulSyncer::Wrapper.new(Faraday.new("http://consul:123")) }

  describe "#request" do
    it "returns object on successful get" do
      stub_request(:get, "http://consul:123/v1/foo/bar").to_return(body: '{"foo": "bar"}')
      consul.request(:get, '/v1/foo/bar').must_equal('foo' => 'bar')
    end

    it "fails and retries on unsuccessful requests" do
      stub_request(:get, "http://consul:123/v1/foo/bar").to_return(body: '{"foo": "bar"}', status: 300)
      consul.expects(:warn).times(4)
      consul.expects(:sleep).times(4)
      e = assert_raises ConsulSyncer::Wrapper::ConsulError do
        consul.request(:get, '/v1/foo/bar')
      end
      e.message.must_equal "Failed to request get http://consul:123/v1/foo/bar: 300 -- {\"foo\": \"bar\"}"
    end

    # Ideally would like to see the url here, but did never happen so far
    it "fails and retries on failed requests" do
      stub_request(:get, "http://consul:123/v1/foo/bar").to_timeout
      consul.expects(:warn).times(4)
      consul.expects(:sleep).times(4)
      e = assert_raises Faraday::Error do
        consul.request(:get, '/v1/foo/bar')
      end
      e.message.must_equal "execution expired"
    end

    it "returns true for successful put" do
      stub_request(:put, "http://consul:123/v1/foo/bar").to_return(body: 'true')
      consul.request(:put, '/v1/foo/bar', foo: :bar).must_equal true
    end
  end
end
