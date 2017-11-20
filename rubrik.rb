$LOAD_PATH.unshift File.expand_path('../lib/', __FILE__)
require 'parseoptions.rb'
require 'pp'
require 'getCreds.rb'
require 'getFromApi.rb'
require 'json'
require 'csv'
require 'getVm.rb'

class Hash
   def Hash.nest
     Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }
   end
end

def livemount (vmids)
  require 'getSlaHash.rb'
  require 'setToApi.rb'
  sla_hash = getSlaHash()
  if Options.unmount
    puts "Checking and Requesting #{vmids.count} Unmounts"
    (getFromApi('rubrik',"/api/v1/vmware/vm/snapshot/mount"))['data'].each do |mount|
      if (vmids.include? mount['vmId']) && mount['isReady']
        puts "Requesting Unmount - (#{findVmItemById(mount['mountedVmId'], 'name')})" 
        setToApi('rubrik',"/api/v1/vmware/vm/snapshot/mount/#{mount['id']}",'',"delete")
      elsif (vmids.include? mount['vmId']) && !mount['isReady']
        puts "Requesting Unmount - (#{findVmItemById(mount['mountedVmId'], 'name')})" 
      end
    end
  end
  if Options.livemount
    puts "Requesting #{vmids.count} Live Mounts"
    vmids.each_with_index do |vm,num|
      vmd = getFromApi('rubrik',"/api/v1/vmware/vm/#{vm}")
      if vmd['snapshots'].empty?
        puts "#{num+1}: Requesting Livemount - #{vmd['name']} (Denied - No Snapshots)"
        next
      end
      puts "#{num+1}: Requesting Livemount - #{vmd['name']} (#{vmd['snapshots'].last['date']})"
      setToApi('rubrik',"/api/v1/vmware/vm/snapshot/#{vmd['snapshots'].last['id']}/mount",'',"post")
    end
  end
end

def odb (vmids)
  require 'getSlaHash.rb'
  sla_hash = getSlaHash()
  puts "Requesting #{vmids.count} Snapshots"
  vmids.each_with_index do |vm,num|
    if Options.assure 
      o = (setToApi('rubrik',"/api/v1/vmware/vm/#{vm}/snapshot",{ "slaId" => "#{sla_hash.key(Options.assure)}" },"post"))['status']
      print "#{num+1} - Requesting backup of #{findVmItemById(vm, 'name')}, setting to #{Options.assure} SLA Domain - #{o}\t\t\t\t\t\t\t\t\t\r"
    else
      o = (setToApi('rubrik',"/api/v1/vmware/vm/#{vm}/snapshot","","post"))['status']
      print "#{num+1} - Requesting backup of #{findVmItemById(vm, 'name')}, not setting SLA domain - #{o}\t\t\t\t\t\t\t\t\t\r"
    end
    STDOUT.flush
  end
  puts
end

def bToG (b)     
  (((b.to_f/1024/1024/1024) * 100) / 100) 
end

def writecsv(row,hdr)
  if csv_exists?
    CSV.open(Options.outfile, 'a+') { |csv| csv << row }
  else
    CSV.open(Options.outfile, 'wb') do |csv|
      csv << hdr
      csv << row
    end
  end
end

def csv_exists?
  @exists ||= File.file?(Options.outfile)
end

def to_g (b)     
  (((b.to_i/1024/1024/1024) * 100) / 100).round 
end

Creds = getCreds();
Begintime=Time.now
Logtime=Begintime.to_i

# Global options
Options = ParseOptions.parse(ARGV)
def logme(machine,topic,detail)
  time=Time.now
  timepx=time.to_i
  return if topic == "Ping"
  File.open(Logtime.to_s + ".txt", 'a') { |f| f.write("#{time}|#{timepx}|" + machine + "|" + topic + "|" + detail + "\n") }
  puts("#{time}|#{timepx}|" + machine + "|" + topic + "|" + detail)
end
# Grab the SLAHash to make pretty names
if Options.file then
  if Options.assure then
    require 'getVm.rb'
    require 'uri'
    ss = URI.encode(Options.assure.to_s)
    managedId=findVmItemByName(Options.vm,'managedId')
    h=getFromApi('rubrik',"/api/v1/search?managed_id=#{managedId}&query_string=#{ss}")
    h['data'].each do |s|
      puts s['path']
    end
  end
end

if Options.fsbackup
  templates = getFromApi('rubrik',"/api/v1/fileset_template")
  filesets = getFromApi('rubrik',"/api/v1/fileset")
  File.open(Logtime.to_s + "_templates.json", 'a') { |f| PP.pp(templates,f) }
  File.open(Logtime.to_s + "_filesets.json", 'a') { |f| PP.pp(filesets,f) }
end

if Options.split && Options.infile && Options.sharename && Options.sharetype
  require 'setToApi.rb'
  require 'getSlaHash.rb'
  sla_hash = getSlaHash()
  host = getFromApi('rubrik',"/api/v1/host?hostname=#{URI::encode(Options.hostname)}")
  if host['total'] == 0
    puts "#{Options.hostname} is not configured on Rubrik"
  else
    hostId = host['data'][0]['id']
    shares = getFromApi('rubrik',"/api/internal/host_fileset/share?hostname=#{URI::encode(Options.hostname)}&share_type=#{URI::encode(Options.sharetype)}")
    if shares['total'] == 0
      puts "No shares configured for #{Options.hostname}"
      exit
    else
      shareId=''
      shares['data'].each do |share|
        if share['exportPoint'] == Options.sharename
          shareId = share['id']
        end
      end
      if shareId == ''
        puts "#{Options.sharename} (#{Options.sharetype}) does not exist on Rubrik for #{Options.hostname}"
        #exit
      end
    end
  end
  puts "Configuring filesets for #{Options.hostname} (#{hostId}) - #{Options.sharename} (#{shareId})"
  depth = 2
  lines = File.open(Options.infile)
  path=''
  par = []
  dirs = {} 
  lines.each do |line|
    if line.include? "Folder fullpath"
      path=line[/fullpath\=\"(.*?)\"/,1]
    elsif line.include? "SizeData"
      count = line[/.*Files\=\"(.*?)\".*/,1]
      size = (line[/.*Size\=\"(.*?)\".*/,1]).to_f/1073741824
      if !path.empty?
        if path.include? "\\"
          path = (path.gsub(/\\/, "/")) 
        end
        path = path.split(Options.sharename)[1]
        path = "#{path}**"
        depth = (path.scan(/(?=\/)/).count) 
        sharepath = "//#{Options.sharename}#{path}"
        dirs[path] = {}
        dirs[path]['size'] = size.to_i
        dirs[path]['sharepath'] = sharepath
        dirs[path]['count'] = count.to_i
        dirs[path]['depth'] = depth.to_i
      end
    end
  end
  dirs.each_key do |d|
    if ((dirs[d]['count'] > 500000 || dirs[d]['size'] > 2000) && dirs[d]['depth'] < 6) || dirs[d]['depth'] == 1
      puts "#{dirs[d]['depth']}|#{dirs[d]['count']}|#{dirs[d]['size']}|#{d}"
    end
  end
  exit
#        if (depth > 1 && depth < 3) && (count.to_i > 200000 || size.to_i > 5000)
#          next if par.include? path
#          par << path
#          path = "#{path}**"
#          op = "No Fileset Operation"
#          if Options.filesetgen && Options.sharename
#            if (getFromApi('rubrik',"/api/v1/fileset_template?name=#{URI::encode(sharepath)}"))['total'] > 0
#              op = "Fileset Exists"
#            else
#              op = "Created Fileset"
#              o = setToApi('rubrik','/api/v1/fileset_template',{ "shareType" => "#{Options.sharetype}", "includes" => ["#{path}"],"name" => "#{sharepath}"} ,"post")
#            end
#            templateId = getFromApi('rubrik',"/api/v1/fileset_template?name=#{URI::encode(sharepath)}")['data'][0]['id']
#            association = ''
#            association = getFromApi('rubrik',"/api/v1/fileset?host_id=#{URI::encode(hostId)}&share_id=#{URI::encode(shareId)}&template_id=#{URI::encode(templateId)}")['total']
#            if association == 0  
#              op2="Create Association"
#              o = setToApi('rubrik','/api/v1/fileset',{ "shareId" => "#{shareId}", "hostId" => "#{hostId}","templateId" => "#{templateId}"} ,"post")['id']
#              if Options.assure
#                slaId = sla_hash.invert[Options.assure]
#                c = setToApi('rubrik',"/api/v1/fileset/#{o}",{ "configuredSlaDomainId" => "#{slaId}"} ,"patch")
#              end
#            else
#              op2="Association Exists"
#            end
#          end
#          puts "#{depth} | #{count} | #{size} | #{path} | #{op} | #{op2}"
#        end
  if Options.filesetgen && Options.sharename
    o = setToApi('rubrik','/api/v1/fileset_template',{ "shareType" => "#{Options.sharetype}", "includes" => "**", "excludes" => par,"name" => "//#{Options.sharename}/CatchAll"} ,"post")
  end
  exit
end

if Options.fsreport 
  puts ('"Share Name","Fileset Name","Snapshot Count","Last Snapshot Date","File Count","Size"')
  shares = {}
  getFromApi('rubrik',"/api/internal/host/share")['data'].each do |sh|
    shares[sh['id']] = sh['exportPoint']
  end
  getFromApi('rubrik',"/api/v1/fileset")['data'].each do |fs|
    size=0
    fileset = getFromApi('rubrik',"/api/v1/fileset/#{fs['id']}")
    next if fileset['configuredSlaDomainName'] != "Milbank NAS Backup SLA"
    getFromApi('rubrik',"/api/v1/fileset/snapshot/#{fileset['snapshots'].last['id']}/browse?path=%2F")['data'].each do |mysize|
      size += mysize['size']
    end
    #date = fileset['snapshots'].last['date'].gsub(/^(.*)T(.*)Z$/, '\1 \2')
    puts ("#{shares[fileset['shareId']]},#{fileset['name']},#{fileset['snapshotCount']},#{fileset['snapshots'].last['date'].gsub(/^(.*)T(.*)Z$/, '\1 \2')},#{fileset['snapshots'].last['fileCount']},#{size}")
  end
end

  

if Options.metric then
  if Options.storage then
    h=getFromApi('rubrik',"/api/internal/stats/system_storage")
  end
  if Options.iostat then
    h=getFromApi('rubrik',"/api/internal/cluster/me/io_stats?range=-#{Options.iostat}")
  end
  if Options.archivebw then
    h=getFromApi('rubrik',"/api/internal/stats/archival/bandwidth/time_series?range=-#{Options.archivebw}")
  end
  if Options.snapshotingest then
    h=getFromApi('rubrik',"/api/internal/stats/snapshot_ingest/time_series?range=-#{Options.snapshotingest}")
  end
  if Options.localingest then
    h=getFromApi('rubrik',"/api/internal/stats/local_ingest/time_series?range=-#{Options.localingest}")
  end
  if Options.physicalingest then
    h=getFromApi('rubrik',"/api/internal/stats/physical_ingest/time_series?range=-#{Options.physicalingest}")
  end
  if Options.runway then
    h=getFromApi('rubrik',"/api/internal/stats/runway_remaining")
  end
  if Options.incomingsnaps then
    h=getFromApi('rubrik',"/api/internal/stats/streams/count")
  end
  if Options.blah then
    puts JSON.pretty_generate(h)
  elsif Options.csv then
    json = JSON.parse(h.to_json)
    puts json.first.collect {|k,v| k}.join(',')
    puts json.collect {|node| "#{node.collect{|k,v| v}.join(',')}\n"}.join
  else
    puts h
  end
end

if Options.vmusage then
  vcenters=getFromApi('rubrik',"/api/v1/vmware/vcenter")['data']
  VmwareVCenters = {}     
  vcenters.each do |vcenter|       
    VmwareVCenters[vcenter['id']] = vcenter['hostname']     
  end
  vdatacenters=getFromApi('rubrik',"/api/internal/vmware/data_center")['data']     
  VmwareDatacenters = {}     
  vdatacenters.each do |datacenter|       
    VmwareVCenters[datacenter['id']] = datacenter['name']     
  end
  s=getFromApi('rubrik',"/api/internal/stats/per_vm_storage")['data'] 
  s.each do |r|
    if r['id'].include? "-vm-" then
      vmr=getFromApi('rubrik',"/api/v1/vmware/vm/VirtualMachine:::#{r['id']}")
      r['vmname']=vmr['name']
      r['vcenter']=VmwareVCenters[vmr['vcenterId']]
      r['datacenter']=VmwareVCenters[vmr['currentHost']['datacenterId']]
      if Options.tag then
        require 'vmOperations.rb'
        #vmstuff = getVm(Creds[r['vcenter']],{"objectName" => r['vmname'],"datacenter" => r['datacenter']})
        #vmstuff.config.extraConfig.each { |x| puts "#{x.key}: #{x.value}" }
      	crap=vmwareFromApi(r['vcenter'],"/rest/com/vmware/cis/tagging/tag/")
        #puts vmstuff.tag
  #      vmstuff.config.each { |x| puts "#{x.key}: #{x.value}" }
        #pp vmstuff.config 
        exit
      end
      r.keys.each do |c|
        if c.include? "Bytes" then
          r[c] = to_g(r[c])
        end
      end 
      next if !r['vmname']
      if !Options.outfile & !defined? Done then
        puts r.keys.to_csv
        Done = 1
      end
      if Options.outfile then
        writecsv(r.values,r.keys)
      else
        puts r.values.to_csv
      end
    end
  end
end 


if Options.envision then
  h=getFromApi('rubrik',"/api/internal/report?search_text=#{Options.envision}")
  h['data'].each do |r|
    if r['name'] == Options.envision then
      o=getFromApi('rubrik',"/api/internal/report/#{r['id']}/table")
      hdr = o['columns']
      if !Options.outfile then 
        puts hdr.to_csv
      end
      o['dataGrid'].each do |e|
        if Options.tag then
          vmr=getFromApi('rubrik',"/api/v1/vmware/vm/#{x['ObjectId']}")
          puts vmr['moid']
        end
        if Options.outfile then
          writecsv(e,hdr)
        else
          puts e.to_csv
        end
      end
    end
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
    id=findVmItemByName(Options.vm,'id')
    #Get Latest Snapshot
    h=getFromApi('rubrik',"/api/v1/vmware/vm/#{id}/snapshot")
    latestSnapshot =  h['data'][0]['id']
    #Get vmWare Hosts for the Cluster
    hostList = Array.new
    o = setToApi('rubrik','/api/v1/vmware/vm/snapshot/' + latestSnapshot + '/instant_recover',{ "vmName" => "#{Options.vm}","hostId" => "#{hostList[0]}","removeNetworkDevices" => true},"post")
    puts '/api/v1/vmware/vm/snapshot/' + latestSnapshot + '/instant_recover'
end

if Options.drcsv then
    require 'CSV'
    require 'getSlaHash.rb'
    require 'getFromApi.rb'
    require 'getVm.rb'
    require 'uri'
    require 'json'
    require 'setToApi.rb'
    require 'vmOperations.rb'
    require 'migrateVM.rb'
    logme("BEGIN","BEGIN",Begintime.to_s)
    logme("Core","Assembling Base Hashes","Started")
  #  (@token,@rubrikhost) = get_token()
    datastores=getFromApi('rubrik',"/api/internal/vmware/datastore")['data']
    logme("Core","Assembling Base Hashes","Infrastructure")
    VmwareDatastores = {}
    datastores.each do |datastore|
      VmwareDatastores[datastore['name']] = datastore['id']
    end
    vcenters=getFromApi('rubrik',"/api/v1/vmware/vcenter")['data']
    VmwareVCenters = {}
    vcenters.each do |vcenter|
      VmwareVCenters[vcenter['id']] = vcenter['hostname']
    end
    vdatacenters=getFromApi('rubrik',"/api/internal/vmware/data_center")['data']
    VmwareDatacenters = {}
    vdatacenters.each do |datacenter|
      VmwareVCenters[datacenter['id']] = datacenter['name']
    end
    clusters=getFromApi('rubrik',"/api/internal/vmware/compute_cluster")['data']
    VmwareClusters = {}
    clusters.each do |cluster|
      VmwareClusters[cluster['id']] = cluster['name']
    end
    hosts=getFromApi('rubrik',"/api/v1/vmware/host")['data']
    temphosts = Hash.nest
    hosts.each do |host|
      hd=getFromApi('rubrik',"/api/v1/vmware/host/#{host['id']}")
      temphosts[VmwareVCenters[hd['datacenter']['vcenterId']]][hd['datacenter']['name']]#[VmwareClusters[hd['computeClusterId']]]
    end
    Infrastructure = temphosts
    hosts.each do |host|
      VmwareHosts[host['id']] = host['name']
      hd=getFromApi('rubrik',"/api/v1/vmware/host/#{host['id']}")
      if Infrastructure[VmwareVCenters[hd['datacenter']['vcenterId']]][hd['datacenter']['name']][VmwareClusters[hd['computeClusterId']]].empty?
        Infrastructure[VmwareVCenters[hd['datacenter']['vcenterId']]][hd['datacenter']['name']][VmwareClusters[hd['computeClusterId']]] = []
      end
      Infrastructure[VmwareVCenters[hd['datacenter']['vcenterId']]][hd['datacenter']['name']][VmwareClusters[hd['computeClusterId']]].push(host['id'])
    end
    logme("Core","Assembling Base Hashes","SLA Domains")
    Sla_hash = getSlaHash()
    logme("Core","Assembling Base Hashes","Succeeded")
    # Read from csv file
    vmlist = CSV.read(Options.infile, {:headers => true})
    pool    = MigrateVM.pool(size: Options.threads.to_i)
    vmlist.map do |row|
      pool.future(:migrate_vm,row)
    end.map(&:value)
  endTimer = Time.now
  runtime = endTimer - Begintime
  logme("END","END",endTimer.to_s + "|" + runtime.to_s)
end

if Options.odb then
  require 'setToApi.rb'
  vmids = []
  if Options.vm then
    vmids << findVmItemByName(Options.vm, 'id')
  end  
  if Options.infile
    (CSV.read(Options.infile, {:headers => true})).each do |vm|
       vmids << findVmItemByName(vm['name'], 'id')
    end
  odb(vmids)
  end
end

if Options.isilon
  require 'securerandom'
  require 'setToApi.rb'
  b = Time.now.to_f 
  isi_path=Options.isilon
  isi_snap_prefix="Rubrik_"
  tm = {}
  tm['Begin'] = Time.now.to_f
  puts "Begin (#{tm['Begin']})" 
  # Get the last Rubrik_ snapshot on the isilon
  isi_last_snap={}
  isi_last_snap_call = "/platform/1/snapshot/snapshots?type=real&dir=DESC"
  isi_last_snap_method = "get"
  puts "Getting last Rubrik_ snap info - \n\t#{isi_last_snap_method} \n\t#{isi_last_snap_call}"
  getFromApi('isilon',isi_last_snap_call)['snapshots'].each do |g|
    if g['name'] =~ /^#{isi_snap_prefix}/ && g['path'] == isi_path
      pp g
      isi_last_snap=g
      break
    end
  end
  if isi_last_snap.empty?
    puts "\tResults - No Checkpoint found for #{Options.isilon}, will create now"
  else
    tm['GetLastSnap'] = (Time.now.to_f - tm['Begin']).round(3)
    puts "\tResults - #{isi_last_snap['name']} (#{isi_last_snap['id']}) (#{tm['GetLastSnap']})"
  end

  # Create a New Snapshot to create changelist
  isi_path=Options.isilon
  isi_snap_name="Rubrik_"+SecureRandom.uuid
  isi_new_snap_call = "/platform/1/snapshot/snapshots"
  isi_new_snap_method = "post"
  isi_new_snap_payload = {"path" => "#{isi_path}", "name" => "#{isi_snap_name}"}
  print "Creating checkpoint Rubrik_ snap - \n\t#{isi_new_snap_method} \n\t#{isi_new_snap_call} \n\t#{isi_new_snap_payload} "
  isi_new_snap = setToApi('isilon',isi_new_snap_call,isi_new_snap_payload,isi_new_snap_method)
  tm['CreateNewSnap'] = (Time.now.to_f - tm['Begin']).round(3)
  puts "\n\tResults -  #{isi_new_snap['name']} (#{isi_new_snap['id']}) (#{tm['CreateNewSnap']})"
  if isi_last_snap.empty?
    puts "Complete - Full file scan must be done to continue this backup"
    exit
  end
  # Create the changelist job to compare the new snapshot with the last one
  isi_new_changelist_call = "/platform/3/job/jobs"
  isi_new_changelist_method = "post"
  isi_new_changelist_payload = { "type" => "changelistcreate", "changelistcreate_params" => {"older_snapid" => isi_last_snap['id'].to_i, "newer_snapid" => isi_new_snap['id'].to_i, "retain_repstate" => true}}
  puts "Create Changelist #{isi_last_snap['id']}_#{isi_new_snap['id']} \n\t#{isi_new_changelist_method} \n\t#{isi_new_changelist_call} \n\t#{isi_new_changelist_payload}"
  changelist_job_id = setToApi('isilon',isi_new_changelist_call,isi_new_changelist_payload,isi_new_changelist_method)['id']

  # Monitor the changelist job
  tm['CreateChangeList'] = (Time.now.to_f - tm['Begin']).round(3)
  last_state = ''
  isi_monitor_changelist_call = "/platform/1/job/jobs/#{changelist_job_id}"
  isi_monitor_changelist_method = "get"
  puts "Monitor changelist job  #{isi_last_snap['name']} to #{isi_new_snap['name']} (#{tm['CreateChangeList']})\n\t#{isi_monitor_changelist_method}\n\t#{isi_monitor_changelist_call}"
  while test = getFromApi('isilon',isi_monitor_changelist_call)['jobs'][0]
    if test['state'] != last_state
      print test['state'].capitalize 
      if test['state'] == 'succeeded'
        puts
        break
      end
      last_state = test['state']
    else 
      print '.'
    end 
  end
  tm['MonitorChangeListJob'] = (Time.now.to_f - tm['Begin']).round(3)
  puts "Changelist Job Complete (#{tm['MonitorChangeListJob']})"
  
  # Delete Older Snap
  #setToApi('isilon',"/platform/3/snapshot/snapshots/#{isi_last_snap['id']}",'', "delete")
 

  # Here we grab the changes
  iter = 1
  tm['Pages']=1
  until !iter
    a= ''
    if iter != 1  
      a= "?resume=#{iter}"
      tm['Pages'] += 1
    end
    isi_dump_changelist_call = "/platform/1/snapshot/changelists/#{isi_last_snap['id']}_#{isi_new_snap['id']}/lins#{a}"
    isi_dump_changelist_method = "get"
    puts "Dump changelist #{isi_last_snap['id']}_#{isi_new_snap['id']} \n\t#{isi_dump_changelist_method}\n\t#{isi_dump_changelist_call}"
    lins=getFromApi('isilon',isi_dump_changelist_call)
    unless tm['ObjectsReturned'] 
      tm['ObjectsReturned'] = 0
    end
    tm['ObjectsReturned'] += lins['total']
    tm['Resumable'] = lins['resume']
    iter = lins['resume']
  end
  tm['DumpChangeList'] = (Time.now.to_f - tm['Begin']).round(3)
  puts "Dump ChangeList Complete (#{tm['DumpChangeList']})"
  pp tm
  exit
end

if (Options.sla || Options.sla.nil?) && !Options.split then
  require 'getSlaHash.rb'
  require 'getFromApi.rb'
  require 'getVm.rb'
  sla_hash = getSlaHash()
  vmids=[]
  if (Options.livemount || Options.unmount) && !Options.infile
    (getFromApi('rubrik',"/api/v1/vmware/vm?is_relic=false&limit=9999&primary_cluster_id=local")['data']).each do |vm|
      if  sla_hash[vm['effectiveSlaDomainId']] == Options.sla 
        vmids << vm['id']
      end
    end
    livemount(vmids)
    exit
  end
  if Options.odb && !Options.infile
    (getFromApi('rubrik',"/api/v1/vmware/vm?is_relic=false&limit=9999&primary_cluster_id=local")['data']).each do |vm|
      if  sla_hash[vm['effectiveSlaDomainId']] == Options.sla 
        puts "#{vm['name']}"
        vmids << vm['id']
      end
    end
    odb(vmids)
    exit
  end
  if Options.get then
    puts (sla_hash[findVmItemByName(Options.vm, 'effectiveSlaDomainId')])
    exit
  end
  if Options.list then
    (getFromApi('rubrik',"/api/v1/vmware/vm?limit=9999"))['data'].each do |s|
      if s['effectiveSlaDomainId'] == 'UNPROTECTED' then
        puts s['name'] + ", " + s['effectiveSlaDomainName'] + ", " + s['effectiveSlaDomainId'] + ", " + s['primaryClusterId']
      else
        if s['primaryClusterId'] == (getFromApi('rubrik',"/api/v1/sla_domain/#{s['effectiveSlaDomainId']}"))['primaryClusterId'] 
          result = "Proper SLA Assignment"
        else
          result = "Check SLA Assignemnt!"
        end
        puts s['name'] + ", " + s['effectiveSlaDomainName'] + ", " + s['effectiveSlaDomainId'] + ", " + s['primaryClusterId'] + ", " + slData['primaryClusterId'] + ", " + result
      end
    end
    exit
  end
  vmids = []
  vtd = []
  vtdv = []
  if Options.vm 
    vmids << findVmItemByName(Options.vm, 'id')
  end
  if Options.os || Options.sr
    # See if tools is installed on the VM and add to array
    puts "Qualifying SLA Membership"
    vms = getFromApi('rubrik',"/api/v1/vmware/vm?is_relic=false&limit=9999&primary_cluster_id=local")['data']
    puts "Checking Tools on #{vms.count} VMs"
    vms.each do |vm|
      if vm['toolsInstalled']
        vmids << vm['id']
      end
    end
    puts " - #{vmids.count} of #{vms.count} have VMTools"
    # If we specifc an array of --os
    if Options.os
      puts "Checking OS on #{vmids.count} VMs"
      vmids.each_with_index do |i,num| 
        print " - #{num+1}\r"
        match = false
        vmos = (findVmItemById(i,'guestOsName'))
        Options.os.each do |o|
          # If OS matches one of the array values
          if vmos && !vmos.empty? && vmos.upcase.include?(o.upcase) 
            match = true
          end
        end
        # Delete from array if there is no OS match
        if !match 
          vtd << i
        end
      end
      puts
      puts " - #{vtd.count} fail the OS check for #{Options.os}"
      vmids = vmids.reject{ |e| vtd.include? e }
    end
    if Options.sr 
      puts "Checking VMDK size on #{vmids.count} VMs"
      vmids.each_with_index do |i,num| 
        print " - #{num+1}\r"
        vmdks = bToG(getVmdkSize(i)).round
        if vmdks.between?(Options.sr[0].to_i,Options.sr[1].to_i)
          next
        else  
          vtdv << i
        end
      end
      puts
      puts " - #{vtdv.count} fail the VMDK check for #{Options.sr} gb total size"
      vmids = vmids.reject{ |e| vtdv.include? e }
    end
    puts "Setting #{vmids.count} to #{Options.assure}"
    $v = true
  end
  vmids.each_with_index do |i,num| 
    if $v
      print " - #{num+1}\r"
    end
    effectiveSla = sla_hash[findVmItemById(i, 'effectiveSlaDomainId')]
    if Options.assure && (effectiveSla != Options.assure) then
      require 'setSla.rb'
      if sla_hash.invert[Options.assure]
        res = setSla(i, sla_hash.invert[Options.assure])
      end
    end
  end
end
