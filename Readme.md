Sync remote services into consul

 - cleaned up removed
 - updates changed
 - adds new

Install
=======

```Bash
gem install consul_syncer
```

Usage
=====

```Ruby
# address = ENV.fetch("CONSUL_HTTP_ADDR") # prefer using standard consul env var
address = 'http://localhost:8500'
syncer = ConsulSyncer.new(address, logger: Logger.new(STDOUT))
syncer.sync(
  [
    {node: 'N', address: 'A', service: 'S', service_id: 'ID', service_address: 'A', port: 123, tags: ['abc']},
    # ...
  ], 
  ['managed-by-consul-syncer']
)
```

When fetching the service itself works, but getting additional info like tags fails `keep: true` can be added
to the definition to make it not update/remove the service. This can be useful when tags come from the actual services metadata
but the service is in trouble somehow.

To identify the origin of consul requests or send other information along, use `params`.
They will get logged in consuls log `consul monitor --log-level=debug` and will tell others who made updates.

```Ruby
ConsulSyncer.new('http://localhost:8500', logger: Logger.new(STDOUT), params: {host: Socket.gethostname, app: 'consul-filler'})
```

Spliting planning and execution to for example add confirmation or inspect the changes.

```ruby
plan = syncer.plan(...)
puts "Planned #{plan.size} changes"
syncer.execute plan
```

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/consul_syncer.png)](https://travis-ci.org/grosser/consul_syncer)
