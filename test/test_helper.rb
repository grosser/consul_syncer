require "bundler/setup"

require "single_cov"
SingleCov.setup :minitest

require "consul_syncer/version"
require "consul_syncer"

require "maxitest/global_must"
require "maxitest/autorun"
require "maxitest/timeout"
require "maxitest/threads"
require "webmock/minitest"
require "mocha/minitest"
