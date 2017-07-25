$LOAD_PATH.unshift File.expand_path('../lib/', __FILE__)
require 'parseoptions.rb'
require 'pp'
require 'getCreds.rb'
require 'json'

# Global options
Options = ParseOptions.parse(ARGV)
Creds = getCreds();

def logme(machine,topic,detail)
  time=Time.now
  return if topic == "Ping"
  File.open('out.log', 'a') { |f| f.write("#{time} : " + machine + " : " + topic + " : " + detail + "\n") }
  puts("#{time} : " + machine + " : " + topic + " : " + detail)
end
# Grab the SLAHash to make pretty names
if Options.file then
  if Options.assure then
    require 'getVm.rb'
    require 'uri'
    # do some file workflow
    ss = URI.encode(Options.assure.to_s)
    managedId=findVmItem(Options.vm,'managedId')
    h=getFromApi("/api/v1/search?managed_id=#{managedId}&query_string=#{ss}")
    h['data'].each do |s|
      puts s['path']
    end
  end
end

if Options.metric then
  require 'getFromApi.rb'
  require 'json'
  if Options.storage then
    h=getFromApi("/api/internal/stats/system_storage")
  end
  if Options.iostat then
    h=getFromApi("/api/internal/cluster/me/io_stats?range=-#{options.iostat}")
  end
  if Options.archivebw then
    h=getFromApi("/api/internal/stats/archival/bandwidth/time_series?range=-#{options.archivebw}")
  end
  if Options.snapshotingest then
    h=getFromApi("/api/internal/stats/snapshot_ingest/time_series?range=-#{options.snapshotingest}")
  end
  if Options.localingest then
    h=getFromApi("/api/internal/stats/local_ingest/time_series?range=-#{options.localingest}")
  end
  if Options.physicalingest then
    h=getFromApi("/api/internal/stats/physical_ingest/time_series?range=-#{options.physicalingest}")
  end
  if Options.runway then
    h=getFromApi("/api/internal/stats/runway_remaining")
  end
  if Options.incomingsnaps then
    h=getFromApi("/api/internal/stats/streams/count")
  end
  if Options.json then
    puts h.to_json
  else
    puts h
  end
end

if Options.login then
   require 'getToken.rb'
   token=get_token()
end


if Options.dr then
    require 'getVm.rb'
    require 'uri'
    require 'json'
    require 'setToApi.rb'
    #Get Cluster ID
    clusterInfo=getFromApi("/api/v1/cluster/me")
    id=findVmItem(Options.vm,'id')
    #Get Latest Snapshot
    h=getFromApi("/api/v1/vmware/vm/#{id}/snapshot")
    latestSnapshot =  h['data'][0]['id']
    #Get vmWare Hosts for the Cluster
    hostList = Array.new
    o = setToApi('/api/v1/vmware/vm/snapshot/' + latestSnapshot + '/instant_recover',{ "vmName" => "#{options.vm}","hostId" => "#{hostList[0]}","removeNetworkDevices" => true},"post")
    puts '/api/v1/vmware/vm/snapshot/' + latestSnapshot + '/instant_recover'
end

if Options.relics
  require 'getFromApi.rb'
  require 'getVm.rb'
  require 'setToApi.rb'
  listData = getFromApi("/api/v1/vmware/vm?limit=9999&primary_cluster_id=local")["data"]
  listData.each do |vm|
    if vm['isRelic']
      a = []
      vmData = getFromApi("/api/v1/vmware/vm/#{vm['id']}")['snapshots']
      vmData.each do |ss|
        age = ((Date.parse Time.now.to_s) - (Date.parse ss['date'])).to_i
        a.push(age)
      end
      if a.min && a.min >= Options.relics.to_i
        puts "#{vm['name']} (#{vm['id']} is Relic : Newest Snapshot #{a.min} Days ago, DELETING ALL SNAPS"
        setToApi("/api/v1/vmware/vm/#{vm['id']}/snapshot",'','delete')
      end
    end
  end
end

if Options.sla then
  require 'getSlaHash.rb'
  require 'getFromApi.rb'
  require 'setToApi.rb'
  require 'getVm.rb'
  sla_hash = getSlaHash()
  if Options.livemount then
    listData = getFromApi("/api/v1/vmware/vm?limit=9999")
    listData['data'].each do |s|
      if s['effectiveSlaDomainName'] == Options.livemount
        h=getFromApi("/api/v1/vmware/vm/#{s['id']}/snapshot")['data'][0]
        puts "Mounting #{s['name']}  #{h['id']}  #{h['date']}"
        setToApi('/api/v1/vmware/vm/snapshot/' + h['id'] + '/mount',{ "hostId" => "#{s['hostId']}", "powerOn" => false},"post")
      end
    end
  else
    if Options.get then
      effectiveSla = sla_hash[findVmItem(Options.vm, 'effectiveSlaDomainId')]
      # Get the SLA Domain for node
      puts "#{effectiveSla}"
    end
    if Options.list then
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
    effectiveSla = sla_hash[findVmItem(Options.vm, 'effectiveSlaDomainId')]
    if Options.assure && (effectiveSla != Options.assure) then
      require 'setSla.rb'
      if Options.assure == effectiveSla
        puts "Looks like its set"
      else
        if sla_hash.invert[Options.assure]
          res = setSla(findVmItem(Options.vm, 'id'), sla_hash.invert[Options.assure])
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
end
