name = "consul_syncer"
require "./lib/#{name.gsub("-","/")}/version"

Gem::Specification.new name, ConsulSyncer::VERSION do |s|
  s.summary = "Sync remote services into consul"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "https://github.com/grosser/#{name}"
  s.files = `git ls-files lib/ bin/ MIT-LICENSE`.split("\n")
  s.license = "MIT"
  s.required_ruby_version = '>= 2.0.0'
end
