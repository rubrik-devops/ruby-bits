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

Metric options:
        --metric                     Return Requested Metric
    -s, --storage                    Return storage capacity information
    -i, --iostat [range]             Return iostat information for range (30sec, 60min, etc)
    -j, --json                       Output in JSON if possible

Experimental options:
        --file                       Experimental - file search and recovery

Common options:
    -n, --node [Address]             Rubrik Cluster Address/FQDN
    -u, --username [username]        Rubrik Cluster Username
    -p, --password [password]        Rubrik Cluster Password
    -h, --help                       Show this message
```

# Examples:
## Get Disk Capacity Metrics from the Rubrik Cluster
```
Command - ruby rubrik.rb -n my.rubrik.cluster -u admin -p password --metric --storage --json
Returns - {"total":59577558938215,"used":9201035200028,"available":50376523738187,"lastUpdateTime":"2017-04-28T12:00:47Z"}
```
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
## Instant Recovery of a Virtual Machine - THIS WILL DEPRECATE THE PRODUCTION VM!!!
```
Command - ruby rubrik.rb --node my.rubrik.cluster --username admin --password password --client my-vm-name --dr
Returns - Nothing on success, Output on Error
```
## List SLA Domains, and cross check primary cluster
```
Command -  ruby rubrik.rb --node my.rubrik.cluster --username admin --password password --sla --list
Returns - CSV (name, SLA Name, SLA ID, Primary Cluster of VM, Primary Cluster of SLA, Suggestion)

VUM1, Unprotected, UNPROTECTED, 5fca952e-d332-4419-bb96-8339d9beb3ac
SE-JRIJNBEE-LINUX, Unprotected, UNPROTECTED, 5fca952e-d332-4419-bb96-8339d9beb3ac
cloudian-node-3, Unprotected, UNPROTECTED, 5fca952e-d332-4419-bb96-8339d9beb3ac
DEMO-SQL12-WFC2, Unprotected, UNPROTECTED, 5fca952e-d332-4419-bb96-8339d9beb3ac
SE-RMILLER-LINUX, Gold, d8a8430c-40de-4cb7-b834-bd0e7de40ed1, 5fca952e-d332-4419-bb96-8339d9beb3ac, 5fca952e-d332-4419-bb96-8339d9beb3ac, Proper SLA Assignment
```
# Use Cases:
* Submit new use cases please

