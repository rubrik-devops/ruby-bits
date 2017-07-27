require 'rbvmomi'

def renameVm(vcenter,vmobj)
  vim = RbVmomi::VIM.connect(host: "#{vcenter['server']}", user: "#{vcenter['username']}", password: "#{vcenter['password']}", insecure: "true")
  dc = vim.serviceInstance.find_datacenter(vmobj['fromDatacenter']) || fail('datacenter not found')
  vm = findvm(dc.vmFolder,vmobj['VMName'])
  begin
    vm.ReconfigVM_Task(:spec => RbVmomi::VIM::VirtualMachineConfigSpec(:name=> "#{vmobj['VMName']}-Migrated")).wait_for_completion
    findvm( dc.vmFolder,"#{vmobj['VMName']}-Migrated")
    logme("#{vm.name}","Rename Origin VM", "Succeeded")
    vim.close
  rescue
    logme("#{vm.name}","Rename Origin VM", "Failed")
  end
end

def shutdownVm(vcenter,vmobj)
  begin
    startTimer = Time.now
    vim = RbVmomi::VIM.connect(host: "#{vcenter['server']}", user: "#{vcenter['username']}", password: "#{vcenter['password']}", insecure: "true")
    dc = vim.serviceInstance.find_datacenter(vmobj['fromDatacenter']) || fail('datacenter not found')
    vm = findvm(dc.vmFolder,vmobj['VMName'])
    puts vm.name
    if vm.runtime.powerState == "poweredOff"
      endTimer = Time.now
      time = endTimer - startTimer
      logme("#{vm.name}","Check Power State",vm.runtime.powerState.capitalize + "|" + time.to_s)
      vim.close
      return
    end
    vm.ShutdownGuest
  rescue StandardError=>e
    logme("#{vm.name}","Check Power State", "#{e}")
  end
  while vm.runtime.powerState == "poweredOn"
    logme("#{vm.name}","Ping",vm.runtime.powerState.capitalize)
  end
  endTimer = Time.now
  time = endTimer - startTimer
  logme("#{vm.name}","Check Power State ", vm.runtime.powerState.capitalize + "|" + time.to_s)
  vim.close
end

def startVm(vcenter,vmobj)
  begin
    vim = RbVmomi::VIM.connect(host: "#{vcenter['server']}", user: "#{vcenter['username']}", password: "#{vcenter['password']}", insecure: "true")
    dc = vim.serviceInstance.find_datacenter(vmobj['fromDatacenter']) || fail('datacenter not found')
    vm = findvm(dc.vmFolder,vmobj['VMName'])
    if vm.runtime.powerState == "poweredOn"
      logme("#{vm.name}","Check Power State", vm.runtime.powerState.capitalize)
      return
    end
    vm.PowerOnVM_Task
  rescue StandardError=>e
    logme("#{vm.name}","Check Power State", "#{e}")
  end
  while vm.runtime.powerState == "poweredOff"
    logme("#{vm.name}","Ping",vm.runtime.powerState)
  end
  logme("#{vm.name}","Checking Power State ", vm.runtime.powerState.capitalize)
end

def checkCD(vcenter,vmobj)
  begin
    vim = RbVmomi::VIM.connect(host: "#{vcenter['server']}", user: "#{vcenter['username']}", password: "#{vcenter['password']}", insecure: "true")
    dc = vim.serviceInstance.find_datacenter(vmobj['fromDatacenter']) || fail('datacenter not found')
    vm = findvm(dc.vmFolder,vmobj['VMName'])
    cd = vm.config.hardware.device.find { |hw| hw.class == RbVmomi::VIM::VirtualCdrom }
    back = RbVmomi::VIM::VirtualCdromRemoteAtapiBackingInfo(deviceName: '')
    spec = RbVmomi::VIM::VirtualMachineConfigSpec(
      deviceChange: [{operation: :edit,
        device: RbVmomi::VIM::VirtualCdrom(
          backing: back, key: cd.key, controllerKey: cd.controllerKey,
          connectable: RbVmomi::VIM::VirtualDeviceConnectInfo(
            startConnected:  false, connected: false, allowGuestControl: true
          )
        )
      }]
    )
    vm.ReconfigVM_Task(spec: spec).wait_for_completion
    logme("#{vm.name}","Reassigning VirtualCdrom", "Complete")
    vim.close
  rescue StandardError=>e
    logme("#{vm.name}","Reassigning VirtualCdrom", "VirtualCdrom Not Found")
  end
end

def vMotion(vcenter,vmobj)
  begin
    startTimer = Time.now
    vim = RbVmomi::VIM.connect(host: "#{vcenter['server']}", user: "#{vcenter['username']}", password: "#{vcenter['password']}", insecure: "true")
    dc = vim.serviceInstance.find_datacenter(vmobj['toDatacenter']) || fail('datacenter not found')
    vm = findvm(dc.vmFolder,vmobj['VMName'])
    ndc = dc.find_datastore(vmobj['toDatastore'])
    migrate_spec = RbVmomi::VIM.VirtualMachineRelocateSpec(datastore: ndc)
    vmotion_task = vm.RelocateVM_Task(spec: migrate_spec)
    status = vmotion_task.info.state
    last_status = status
    while status != "success"
      status = vmotion_task.info.state
      if status != last_status
        endTimer = Time.now
        time = endTimer - startTimer
        logme("#{vm.name}","VMotion Status",status.capitalize + "|" + time.to_s)
      end
      sleep 5
      last_status = status
      logme("#{vm.name}","Ping", status)
    end
    vim.close
  rescue StandardError=>e
    puts e
    logme("#{vm.name}","VMotion ERROR", "#{e}")
  end
end

def checkManagedBy(vcenter,vmobj)
  begin
    vim = RbVmomi::VIM.connect(host: "#{vcenter['server']}", user: "#{vcenter['username']}", password: "#{vcenter['password']}", insecure: "true")
    dc = vim.serviceInstance.find_datacenter(vmobj['fromDatacenter']) || fail('datacenter not found')
    vm = findvm(dc.vmFolder,vmobj['VMName'])
    if vm.config.managedBy
      vm_cfg = {:managedBy => {:extensionKey => '',:type => ''  } }
      task = vm.ReconfigVM_Task(spec: vm_cfg).wait_for_completion
      logme("#{vm.name}","Clear spec.managedBy", "Complete")
    elsif !vm.config.managedBy
      logme("#{vm.name}","Clear spec.managedBy", "Already Clear")
    end
    vim.close
  rescue StandardError=>e
    logme("#{vm.name}","Clear spec.managedBy", "#{e}")
  end
end

def changePortGroup(vcenter,vmobj)
  begin
    vim = RbVmomi::VIM.connect(host: "#{vcenter['server']}", user: "#{vcenter['username']}", password: "#{vcenter['password']}", insecure: "true")
    dc = vim.serviceInstance.find_datacenter(vmobj['toDatacenter']) || fail('datacenter not found')
    vm = findvm(dc.vmFolder,vmobj['VMName'])
    port = dc.network.select{ |pg| pg.name == vmobj['toPortGroup'] }
    dnic = vm.config.hardware.device.grep(RbVmomi::VIM::VirtualEthernetCard).find{|nic| nic.props}
    pp dnic
    if dnic[:connectable][:startConnected].eql?false
      dnic[:connectable][:startConnected] = true
      dnic[:backing][:port][:portgroupKey] = port[0].key
      dnic[:backing][:port][:portKey] = ''
      dnic[:backing][:useAutoDetect] = true
      dnic[:backing][:port][:switchUuid] = port[0].config.distributedVirtualSwitch.uuid
      spec = RbVmomi::VIM.VirtualMachineConfigSpec({
          :deviceChange => [{
              :operation => :edit,
              :device => dnic
          }]
      })
      pp dnic
      vm.ReconfigVM_Task(:spec => spec).wait_for_completion
      logme("#{vmobj['VMName']}","Set NIC to CaPO", "Succeeded")
    else
      logme("#{vmobj['VMName']}","Set NIC to CaPO", "Succeeded")
    end
  rescue StandardError=>e
    logme("#{vmobj['VMName']}","Set NIC to CaPO", "#{e}")
  end
end

# Need to check runtime.inMaintenanceMode
def checkMaintenanceMode(vcenter,host,vmobj)
  begin
    vim = RbVmomi::VIM.connect(host: "#{vcenter['server']}", user: "#{vcenter['username']}", password: "#{vcenter['password']}", insecure: "true")
    dc = vim.serviceInstance.find_datacenter(vmobj['toDatacenter']) || fail('datacenter not found')
    h = findhost(dc.hostFolder,host[0])
    if h.to_s != "0"
      return h.runtime.inMaintenanceMode.to_s
    end
  rescue StandardError=>e
    logme("#{vmobj['VMName']}","Checking host maintenance mode", "#{e}")
  end
end

def findhost(folder,name)
  name = name[0]
  children = folder.children.find_all
  children.each do |child|
    if child.class == RbVmomi::VIM::HostSystem
      if (child.to_s.include?name)
        found = child
      else
        next
      end
    elsif child.class == RbVmomi::VIM::ClusterComputeResource
      child.host.each do |x|
        if (x.to_s[name])
          found = x
        else
          next
        end
      end
    elsif child.class == RbVmomi::VIM::ComputeResource
      if (child.itself.to_s[name])
        found = x
      else
        next
      end
    elsif child.class == RbVmomi::VIM::HostFolder
      found = findhost(child,name)
    end
    if found.class == RbVmomi::VIM::HostSystem
      return found
    else
      return 0
    end
  end
end

def findvm(folder,name)
  children = folder.children.find_all
  children.each do |child|
    if child.class == RbVmomi::VIM::VirtualMachine
      if (child.name == name)
        found = child
      else
        next
      end
    elsif child.class == RbVmomi::VIM::Folder
      found = findvm(child,name)
    end
    if found.class == RbVmomi::VIM::VirtualMachine
      return found
    end
  end
end
