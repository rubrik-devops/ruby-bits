ruby-bits
===============

Generic ruby bits to be organized and used in chef/puppet environments, and as a stand alone utility

# Overview:
* Rubrik Framework for issuing commands in Ruby

# How to use:
```
.creds - JSON formatted configuration (or resort to including credentials in command line execution)

        {
        	"rubrik": {
                	"servers":["ip","ip",...],
                	"username": "[username]",
                	"password": "[password]"
        	}
        }


        Usage: rubrik.rb [options]

        Common options:
            -n, --node [Address]             Rubrik Cluster Address/FQDN
            -u, --username [username]        Rubrik Cluster Username
            -p, --password [password]        Rubrik Cluster Password
            -h, --help                       Show this message

        Specific options:
            -c, --client [name]              Name of Virtual Machine to perform operation for
                --dr                         Instant Recovery of --client
                --relics [days]              Remove Relic VMs after [n] days of inactivity
                --sla                        Perform and SLA Operation (used with --get or --assure or --livemount
                    --list                       Audit SLA configuration
                    -g, --get                        Get Current SLA for [client]
                    -a, --assure [string]            Set SLA for [client])
                    --livemount [SLA]            Perform Live Mount of all VMs in [SLA] Domain
                        --unmount                    Umount all currently Live Mounted VMs in [SLA] Domain

        Metric options:
                --metric                     Return Requested Metric
                    --storage                    Return storage capacity information
                    --incoming                   Return the number of currently incoming snapshots
                    --runway                     Return the available runway in days
                    --iostat [range]             Return iostat information for range (30sec, 60min, etc)
                    --archivebw [range]          Return archive bandwidth information for range (30sec, 60min, etc)
                    --physicalingest [range]     Return physical ingest bandwidth information for range (30sec, 60min, etc)
                    --localingest [range]        Return local ingest bandwidth information for range (30sec, 60min, etc)
                    --snapshotingest [range]     Return snapshot ingest bandwidth information for range (30sec, 60min, etc)
                        -j, --json                       Output in JSON if possible
        
        Experimental options:
                --file                       Experimental - file search and recovery
```

# Examples:
## Live Mount all latest snapshots for each VM in a SLA Domain
### Live Mount
```
Command - ruby .\rubrik.rb --sla --livemount Silver -u admin -p password -n my.rubrik.cluster
Mounting win018  19e38c78-e10d-4c06-a009-3de2da2cb41f  2017-08-01T13:04:35Z
```
### Unmount
```
Command - ruby .\rubrik.rb --sla --livemount Silver --unmount -u admin -p password -n my.rubrik.cluster
Unmounting 'win018 08-01 13:04 2'
```
## Delete all snapshots for VMs if Relic for over N days
```
Command - ruby .\rubrik.rb --relics [number of days] -u admin -p password -n my.rubrik.cluster
DNP-Junk-SW (VirtualMachine:::d0394ed7-a4b3-4c5f-8ecc-5a8199fa007f-vm-3791 is Relic : Newest Snapshot 19 Days ago, DELETING ALL SNAPS
```
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
