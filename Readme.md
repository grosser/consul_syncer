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
syncer = ConsulSyncer.new('http://localhost:8500', logger: Logger.new(STDOUT))
syncer.sync(
  [
    {node: 'N', address: 'A', service: 'S', service_id: 'ID', port: 123, tags: ['abc']},
    # ...
  ], 
  ['managed-by-consul-syncer']
)  
```

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/consul_syncer.png)](https://travis-ci.org/grosser/consul_syncer)
