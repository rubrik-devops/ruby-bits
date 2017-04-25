ruby-bits
===============

Generic ruby bits to be organized and used in chef/puppet environments

# Overview:
* Rubrik Framework for issuing commands in Ruby 

# How to use:
```
Usage: rubrik.rb [options]

Specific options:
    -l, --login                      Perform no operations but return authentication token
    -c, --client [name]              Name of Virtual Machine to perform operation for
    -g, --get                        Perform GET operation
    -a, --assure [string]            String to set in SET operation (in case of --sla, it's the SLA Name)
        --dr                         Instant Recovery of --client
        --sla                        Perform and SLA Operation (used with --get or --assure
        --list                       Audit SLA configuration (used with --sla)
        --file                       Experimental - file search and recovery

Common options:
    -n, --node [Address]             Rubrik Cluster Address/FQDN
    -u, --username [username]        Rubrik Cluster Username
    -p, --password [password]        Rubrik Cluster Password
    -h, --help                       Show this message
```

# Use Cases:
* Rubrik SLA Policies by Role
* Submit new use cases please

#Thanks to:
