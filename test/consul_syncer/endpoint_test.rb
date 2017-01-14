# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ConsulSyncer::Endpoint do
  describe "#name" do
    it "is the ServiceName" do
      ConsulSyncer::Endpoint.new('Service' => {'Service' => 'x'}).name.must_equal 'x'
    end
  end

  describe "#port" do
    it "is the ServicePort" do
      ConsulSyncer::Endpoint.new('Service' => {'Port' => 123}).port.must_equal 123
    end
  end

  describe "#ip" do
    it "is the Address" do
      ConsulSyncer::Endpoint.new('Node' => {'Address' => '1.2.3.4'}).ip.must_equal '1.2.3.4'
    end
  end

  describe "#tags" do
    it "is the ServiceTags" do
      ConsulSyncer::Endpoint.new('Service' => {'Tags' => ['x']}).tags.must_equal ['x']
    end
  end

  describe "#service_id" do
    it 'is ServiceId' do
      ConsulSyncer::Endpoint.new('Service' => {'ID' => 'x'}).service_id.must_equal 'x'
    end
  end

  describe "#node" do
    it 'is Node' do
      ConsulSyncer::Endpoint.new('Node' => {'Node' => 'x'}).node.must_equal 'x'
    end
  end
end
