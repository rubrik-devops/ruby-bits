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

# Examples:
## Check the SLA Domain of a Virtual Machine
```
Command - ruby rubrik.rb --node my.rubrik.cluster --username admin --password password --client my-vm-name --get --sla
Returns - Silver
```
## Set the SLA of a Virtual Machine
```
Command - ruby rubrik.rb --node my.rubrik.cluster --username admin --password password --client my-vm-name --assure Bronze --sla
Returns - Nothing on success, Output on Error
```
## Check the SLA Domain of a Virtual Machine after setting
```
Command - ruby rubrik.rb --node my.rubrik.cluster --username admin --password password --client my-vm-name --get --sla
Returns - Bronze
```
# Use Cases:
* Rubrik SLA Policies by Role
* Submit new use cases please

#Thanks to:
