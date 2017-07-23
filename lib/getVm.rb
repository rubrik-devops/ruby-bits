#$LOAD_PATH.unshift File.expand_path('./', __FILE__)
require 'getFromApi.rb'
# Grab Requested [item] from hash and return ony that value
def findVmItem(t, item, vc = nil)
	t = t.upcase
	h = Hash[getFromApi('/api/v1/vmware/vm?is_relic=false&name='+t)]
	h['data'].each do |v|
		if v['name'].upcase == t and v['isRelic'] == false
			if vc and VmwareVCenters[v['vcenterId']] == vc
				return v[item]
			elsif !vc
				return v[item]
			end
		else
			return "NOT FOUND"
		end
	end
end
