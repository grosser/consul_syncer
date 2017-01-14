require "bundler/setup"

require "single_cov"
SingleCov.setup :minitest

require "consul_syncer/version"
require "consul_syncer"

require "maxitest/autorun"
require "webmock/minitest"
require "mocha/mini_test"
