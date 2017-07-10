require 'rbvmomi'
def shutdownVm(vcenter,vcenteruser,vcenterpw,datacenter,vmname)
  begin
    vim = RbVmomi::VIM.connect(host: "#{vcenter}", user: "#{vcenteruser}", password: "#{vcenterpw}", insecure: "true")
    dc = vim.serviceInstance.find_datacenter(datacenter) || fail('datacenter not found')
    vm = dc.find_vm(vmname) || fail("VM not found #{vmname}")
    if vm.runtime.powerState == "poweredOff"
      logme("#{vm.name}","Check Power State",vm.runtime.powerState)
      return
    end
    vm.ShutdownGuest
  rescue StandardError=>e
    puts "Error: #{vm.name} - #{e}"
  end
  while vm.runtime.powerState == "poweredOn"
    sleep 5
  end
  logme("#{vm.name}","Check Power State ", vm.runtime.powerState)
end
def startVm(vcenter,vcenteruser,vcenterpw,datacenter,vmname)
  begin
    vim = RbVmomi::VIM.connect(host: "#{vcenter}", user: "#{vcenteruser}", password: "#{vcenterpw}", insecure: "true")
    dc = vim.serviceInstance.find_datacenter(datacenter) || fail('datacenter not found')
    vm = dc.find_vm(vmname) || fail("VM not found #{vmname}")
    if vm.runtime.powerState == "poweredOn"
      logme("#{vm.name}","Check Power State", vm.runtime.powerState)
      return
    end
    vm.PowerOnVM_Task
  rescue StandardError=>e
    puts "Error: #{e}"
  end
  while vm.runtime.powerState == "poweredOff"
    sleep 5
  end
  logme("#{vm.name}","Checking Power State ", vm.runtime.powerState)
end
