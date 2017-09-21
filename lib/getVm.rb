#$LOAD_PATH.unshift File.expand_path('./', __FILE__)
require 'getFromApi.rb'

# Grab Requested [item] from hash and return ony that value

def findVmItemByName(t, item)
  t = t.upcase
  begin
    h = getFromApi('/api/v1/vmware/vm?is_relic=false&name='+t)
    h['data'].each do |v|
      if v['name'].upcase == t
        return v[item]
      end
    end
    return false
  rescue StandardError => e
    return false
  end
end

def findVmItemById(t, item)
  begin
    h = getFromApi("/api/v1/vmware/vm/#{t}")
    return h[item]
  rescue StandardError => e
    return false
  end
end
 
def getVmdkSize(id)
  begin
    h = getFromApi("/api/v1/vmware/vm/#{id}")
    sa = []
    h['virtualDiskIds'].each do |d|
      sa << getFromApi("/api/v1/vmware/vm/virtual_disk/#{d}")['size'] 
    end
    return sa.inject(:+)
  rescue StandardError => e
    return false
  end
end
