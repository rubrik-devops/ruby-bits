require 'celluloid'

class MigrateVM
  include Celluloid
# Get vmWare Hosts for the Cluster, merging vcenter name into the hash
  def migrate_vm(vmobj)
    vcenters=getFromApi("/api/v1/vmware/vcenter")
    vmwareVCenters = {}
    vcenters["data"].each do |vcenter|
      vmwareVCenters[vcenter['id'].scan(/^.*\:+(\w{8}-\w{4}-\w{4}-\w{4}-\w{12})/)] = vcenter['name']
    end
    vmwareHosts=getFromApi("/api/v1/vmware/host")
    hosts = []
    vmwareHosts["data"].each do |vmwareHosts|
      vcenterId = vmwareHosts['computeClusterId'].scan(/^.*\:+(\w{8}-\w{4}-\w{4}-\w{4}-\w{12})-.*$/)
      host = {  "id" => vmwareHosts["id"],
                "name" => vmwareHosts["name"],
                "vcenterName" => vmwareVCenters[vcenterId]}
      hosts.push(host)
    end
    pp hosts
    sla_hash = getSlaHash()

#    vmlist.each do |vmobj|
    logme("#{vmobj['VMName']}","Begin Workflow","Begin Workflow")

# Shutdown the VM and monitor to completion
    shutdownVm(vmobj['fromVCenter'],@options.vcenteruser,@options.vcenterpw,vmobj['fromDatacenter'],vmobj['VMName'])

# Snapshot the VM and monitor to completion
    id=findVmItem(vmobj['VMName'],'id')
    effectiveSla = sla_hash[findVmItem(vmobj['VMName'], 'effectiveSlaDomainId')]
    logme("#{vmobj['VMName']}","Request Snapshot",id)
    snapshot_job = JSON.parse(setToApi('/api/v1/vmware/vm/' + id + '/snapshot','',"post"))['id']
    logme("#{vmobj['VMName']}","Monitor Snapshot Request",snapshot_job)
    snapshot_status = ''
    last_snapshot_status = ''
    while snapshot_status != "SUCCEEDED"
      snapshot_status = getFromApi('/api/v1/vmware/vm/request/' + snapshot_job)['status']
      if snapshot_status != last_snapshot_status
        logme("#{vmobj['VMName']}","Monitor Snapshot",snapshot_status)
      end
      last_snapshot_status = snapshot_status
      sleep(5)
    end

# Perform Instant Recovery to new cluster hosts with poweredOff
    h=getFromApi("/api/v1/vmware/vm/#{id}/snapshot")
    latestSnapshot =  h['data'][0]['id']
    logme("#{vmobj['VMName']}","Get Snapshot ID",latestSnapshot)


    logme("#{vmobj['VMName']}","Get VMWare Hosts from Rubrik","NOT DONE YET")
#o = setToApi('/api/v1/vmware/vm/snapshot/' + latestSnapshot + '/instant_recover',{ "vmName" => "#{@options.vm}","hostId" => "#{hostList[0]}","removeNetworkDevices" => true},"post")
#puts '/api/v1/vmware/vm/snapshot/' + latestSnapshot + '/instant_recover'

# Perform Instant Recovery
    logme("#{vmobj['VMName']}","Request Instant Recovery","NOT DONE YET")

# Swap the PortGroup (Don't know how this happens yet)
    logme("#{vmobj['VMName']}","Change Port Group","NOT DONE YET")

# Start the VM
    startVm(vmobj['toVCenter'],@options.vcenteruser,@options.vcenterpw,vmobj['toDatacenter'],vmobj['VMName'])

# VMotion to production storage
    logme("#{vmobj['VMName']}","VMotion from Rubrik","NOT DONE YET")

# Remove Instant Recover from Rubrik
    logme("#{vmobj['VMName']}","Remove Instant Recovery","NOT DONE YET")

  end

    #Get Cluster ID
    #clusterInfo=getFromApi("/api/v1/cluster/me")
    #id=findVmItem(@options.vm,'id')
    #Get Latest Snapshot
    #h=getFromApi("/api/v1/vmware/vm/#{id}/snapshot")
    #latestSnapshot =  h['data'][0]['id']
    #Get vmWare Hosts for the Cluster
    #vmwareHosts=getFromApi("/api/v1/vmware/host")
    #hostList = Array.new
    #vmwareHosts["data"].each do |vmwareHosts|
    #    hostList.push(vmwareHosts["id"]) if vmwareHosts["primaryClusterId"] === clusterInfo["id"]
    #end
    #o = setToApi('/api/v1/vmware/vm/snapshot/' + latestSnapshot + '/instant_recover',{ "vmName" => "#{@options.vm}","hostId" => "#{hostList[0]}","removeNetworkDevices" => true},"post")
    #puts '/api/v1/vmware/vm/snapshot/' + latestSnapshot + '/instant_recover'
end
