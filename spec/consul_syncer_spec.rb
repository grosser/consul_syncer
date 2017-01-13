require "spec_helper"

SingleCov.covered!

describe ConsulSyncer do
  it "has a VERSION" do
    expect(ConsulSyncer::VERSION).to match(/^[\.\da-z]+$/)
  end
end
