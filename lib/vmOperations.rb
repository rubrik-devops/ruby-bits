require 'rbvmomi'
def shutdownVm(vcenter,vcenteruser,vcenterpw,datacenter,vmname)
  puts "Begin Shutdown"
  begin
    vim = RbVmomi::VIM.connect(host: "#{vcenter}", user: "#{vcenteruser}", password: "#{vcenterpw}", insecure: "true")
    dc = vim.serviceInstance.find_datacenter(datacenter) || fail('datacenter not found')
    vm = dc.find_vm(vmname) || fail("VM not found #{vmname}")
    if vm.runtime.powerState == "poweredOff"
      puts "Machine is already Off"
      return
    end
    vm.ShutdownGuest
  rescue StandardError=>e
    puts "Error: #{vm.name} - #{e}"
  end
  while vm.runtime.powerState == "poweredOn"
    puts "Checking state " + vm.runtime.powerState
    sleep 5
  end
  puts "Checking state " + vm.runtime.powerState
  puts "End Shutdown"
end
def startVm(vcenter,vcenteruser,vcenterpw,datacenter,vmname)
  puts "Begin Startup"
  begin
    vim = RbVmomi::VIM.connect(host: "#{vcenter}", user: "#{vcenteruser}", password: "#{vcenterpw}", insecure: "true")
    dc = vim.serviceInstance.find_datacenter(datacenter) || fail('datacenter not found')
    vm = dc.find_vm(vmname) || fail("VM not found #{vmname}")
    if vm.runtime.powerState == "poweredOn"
      puts "Machine is already On"
      return
    end
    vm.PowerOnVM_Task
  rescue StandardError=>e
    puts "Error: #{e}"
  end
  while vm.runtime.powerState == "poweredOff"
    puts "Checking state " + vm.runtime.powerState
    sleep 5
  end
  puts "Checking state " + vm.runtime.powerState
  puts "End Startup"
end
