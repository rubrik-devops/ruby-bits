require 'celluloid/current'


class MigrateVM
  include Celluloid

# Get vmWare Hosts for the Cluster, merging vcenter name into the hash
  def migrate_vm(vmobj)
    starttimerWork = Time.now
    logme("#{vmobj['VMName']}","Begin Workflow","#{self.current_actor}")

# Shutdown the VM and monitor to completion
    logme("#{vmobj['VMName']}","Checking Power State","Started")
    shutdownVm(Creds["fromVCenter"],vmobj)

# Disconnect CD's
    logme("#{vmobj['VMName']}","Checking VirtualCdrom","Started")
    checkCD(Creds["fromVCenter"],vmobj)

# Need to remove custom config (spec.managedBy.extensionKey)
    logme("#{vmobj['VMName']}","Check spec.managedBy","Started")
    checkManagedBy(Creds["fromVCenter"],vmobj)

# Snapshot the VM and monitor to completion
    id=findVmItem(vmobj['VMName'],'id',vmobj['fromVCenter'])
    if id == "NOT FOUND"
      logme("#{vmobj['VMName']}","Find on Rubrik","Not Found")
    end
    effectiveSla = Sla_hash[findVmItem(vmobj['VMName'], 'effectiveSlaDomainId')]
    startTimer = Time.now
    logme("#{vmobj['VMName']}","Request Snapshot",id)
    snapshot_job = JSON.parse(setToApi('/api/v1/vmware/vm/' + id + '/snapshot','',"post"))['id']
    logme("#{vmobj['VMName']}","Monitor Snapshot Request",snapshot_job)
    snapshot_status = ''
    last_snapshot_status = ''
    while snapshot_status != "SUCCEEDED"
      snapshot_status = getFromApi('/api/v1/vmware/vm/request/' + snapshot_job)['status']
      if snapshot_status != last_snapshot_status
        endTimer = Time.now
        time = endTimer - startTimer
        logme("#{vmobj['VMName']}","Monitor Snapshot",snapshot_status.capitalize  + "|" + time.to_s)
        sleep 5
      end
      last_snapshot_status = snapshot_status
      logme("#{vmobj['VMName']}","Ping",snapshot_status)
    end

# Rename the original VM
    logme("#{vmobj['VMName']}","Renaming Origin VM","Bypassed for tests")
#    renameVm(Creds["fromVCenter"],vmobj)


# Retrieve the latest snaphot it Instant Recover
    h=getFromApi("/api/v1/vmware/vm/#{id}/snapshot")
    latestSnapshot =  h['data'][0]['id']
    logme("#{vmobj['VMName']}","Get Snapshot ID",latestSnapshot)

# Need to get rubrik host ids for clustername
    myh=Infrastructure[vmobj['toVCenter']][vmobj['toDatacenter']][vmobj['toCluster']].sample(1)[0]
    logme("#{vmobj['VMName']}","Assign New Host","#{myh}")

# Instant Recover the VM
    logme("#{vmobj['VMName']}","Request Instant Recovery",id)
    startTimer = Time.now
    recovery_job = JSON.parse(setToApi('/api/v1/vmware/vm/snapshot/' + latestSnapshot + '/mount',{ "vmName" => "#{vmobj['VMName']}","hostId" => "#{myh}", "disableNetwork" => false, "removeNetworkDevices" => false, "powerOn" => false},"post"))['id']
    logme("#{vmobj['VMName']}","Instant Recovery Request",recovery_job)
    recovery_status = ''
    last_recovery_status = ''
    while recovery_status != "SUCCEEDED"
      recovery_status = getFromApi('/api/v1/vmware/vm/request/' + recovery_job)['status']
      if recovery_status != last_recovery_status
        endTimer = Time.now
        time = endTimer - startTimer
        logme("#{vmobj['VMName']}","Monitor Recovery",recovery_status.capitalize + "|" + time.to_s)
        sleep 5
      end
      last_recovery_status = recovery_status

      logme("#{vmobj['VMName']}","Ping",recovery_status)
    end

# VMotion to production storage
    logme("#{vmobj['VMName']}","VMotion from Rubrik","Started")
    vMotion(Creds["toVCenter"],vmobj)


# Swap the PortGroup (Don't know how this happens yet)
    logme("#{vmobj['VMName']}","Change Port Group","Started")
    changePortGroup(Creds["toVCenter"],vmobj)

# Set Network Connect on Power
    logme("#{vmobj['VMName']}","Connect Network on Power","NOT DONE")

# Start the VM
#    startVm(Creds["toVCenter"],vmobj)

# Remove Instant Recover from Rubrik
    logme("#{vmobj['VMName']}","Remove Live Mount","Started")
    recovery_result = getFromApi('/api/v1/vmware/vm/request/' + recovery_job)['links']
    recovery_result.each do |r|
      mount = nil
      if r['rel'] == "result"
        mount = r['href'].scan(/^.*(\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$)/).flatten
        setToApi("/api/v1/vmware/vm/snapshot/mount/"+mount[0],"","delete")
      end
    end
    timeWork = Time.now - starttimerWork
    logme("#{vmobj['VMName']}","Work Complete","#{self.current_actor}|" + timeWork.to_s)
  end
end
