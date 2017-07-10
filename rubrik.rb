$LOAD_PATH.unshift File.expand_path('../lib/', __FILE__)
require 'parseoptions.rb'
require 'pp'

# Global options
@options = ParseOptions.parse(ARGV)
def logme(machine,topic,detail)
  time=Time.now
  puts("#{time} : " + machine + " : " + topic + " : " + detail)
end
# Grab the SLAHash to make pretty names
if @options.file then
  if @options.assure then
    require 'getVm.rb'
    require 'uri'
    # do some file workflow
    ss = URI.encode(@options.assure.to_s)
    managedId=findVmItem(@options.vm,'managedId')
    h=getFromApi("/api/v1/search?managed_id=#{managedId}&query_string=#{ss}")
    h['data'].each do |s|
      puts s['path']
    end
  end
end

if @options.metric then
  require 'getFromApi.rb'
  require 'json'
  if @options.storage then
    h=getFromApi("/api/internal/stats/system_storage")
  end
  if @options.iostat then
    h=getFromApi("/api/internal/cluster/me/io_stats?range=-#{@options.iostat}")
  end
  if @options.archivebw then
    h=getFromApi("/api/internal/stats/archival/bandwidth/time_series?range=-#{@options.archivebw}")
  end
  if @options.snapshotingest then
    h=getFromApi("/api/internal/stats/snapshot_ingest/time_series?range=-#{@options.snapshotingest}")
  end
  if @options.localingest then
    h=getFromApi("/api/internal/stats/local_ingest/time_series?range=-#{@options.localingest}")
  end
  if @options.physicalingest then
    h=getFromApi("/api/internal/stats/physical_ingest/time_series?range=-#{@options.physicalingest}")
  end
  if @options.runway then
    h=getFromApi("/api/internal/stats/runway_remaining")
  end
  if @options.incomingsnaps then
    h=getFromApi("/api/internal/stats/streams/count")
  end
  if @options.json then
    puts h.to_json
  else
    puts h
  end
end

if @options.login then
   require 'getToken.rb'
   token=get_token()
end


if @options.dr then
    require 'getVm.rb'
    require 'uri'
    require 'json'
    require 'setToApi.rb'
    #Get Cluster ID
    clusterInfo=getFromApi("/api/v1/cluster/me")
    id=findVmItem(@options.vm,'id')
    #Get Latest Snapshot
    h=getFromApi("/api/v1/vmware/vm/#{id}/snapshot")
    latestSnapshot =  h['data'][0]['id']
    #Get vmWare Hosts for the Cluster
    vmwareHosts=getFromApi("/api/v1/vmware/host")
    hostList = Array.new
    vmwareHosts["data"].each do |vmwareHosts|
	hostList.push(vmwareHosts["id"]) if vmwareHosts["primaryClusterId"] === clusterInfo["id"]
    end
    o = setToApi('/api/v1/vmware/vm/snapshot/' + latestSnapshot + '/instant_recover',{ "vmName" => "#{@options.vm}","hostId" => "#{hostList[0]}","removeNetworkDevices" => true},"post")
    puts '/api/v1/vmware/vm/snapshot/' + latestSnapshot + '/instant_recover'
end

if @options.drcsv then
    require 'CSV'
    require 'getSlaHash.rb'
    require 'getFromApi.rb'
    require 'getVm.rb'
    require 'uri'
    require 'json'
    require 'setToApi.rb'
    require 'vmOperations.rb'
    require 'Parallel'
# setup Threading
    count  = 4
    result = []
    mutex  = Mutex.new
    queue  = Queue.new

# Get vmWare Hosts for the Cluster, merging vcente name into the hash
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

# Read from csv file
    vmlist = CSV.read(@options.infile, {:headers => true})

# Iterate the list, this is where we will fork out when the time comes\
    Parallel.map(vmlist) do |vmobj|
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



if @options.sla then
  require 'getSlaHash.rb'
  require 'getFromApi.rb'
  require 'getVm.rb'
  sla_hash = getSlaHash()
  if @options.get then
    effectiveSla = sla_hash[findVmItem(@options.vm, 'effectiveSlaDomainId')]
    # Get the SLA Domain for node
    puts "#{effectiveSla}"
  end
  if @options.list then
    listData = getFromApi("/api/v1/vmware/vm?limit=9999")
    listData['data'].each do |s|
      lookupSla = s['effectiveSlaDomainId']
      if lookupSla == 'UNPROTECTED' then
        puts s['name'] + ", " + s['effectiveSlaDomainName'] + ", " + s['effectiveSlaDomainId'] + ", " + s['primaryClusterId']
      else
        slData = getFromApi("/api/v1/sla_domain/#{lookupSla}")
        if s['primaryClusterId'] == slData['primaryClusterId'] then
          result = "Proper SLA Assignment"
        else
          result = "Check SLA Assignemnt!"
        end
        puts s['name'] + ", " + s['effectiveSlaDomainName'] + ", " + s['effectiveSlaDomainId'] + ", " + s['primaryClusterId'] + ", " + slData['primaryClusterId'] + ", " + result
      end
    end
    exit
  end
  effectiveSla = sla_hash[findVmItem(@options.vm, 'effectiveSlaDomainId')]
  if @options.assure && (effectiveSla != @options.assure) then
    require 'setSla.rb'
    if @options.assure == effectiveSla
      puts "Looks like its set"
    else
      if sla_hash.invert[@options.assure]
        res = setSla(findVmItem(@options.vm, 'id'), sla_hash.invert[@options.assure])
        if !res.nil?
	  res = JSON.parse(res)
         # if res["effectiveSlaDomain"]["name"] == @options.assure
         #   puts "#{@options.assure}"
         # end
        else
          puts "Rubrik SLA Domain does NOT exist, cannot comply"
        end
      end
    end
  end
end
