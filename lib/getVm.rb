#$LOAD_PATH.unshift File.expand_path('./', __FILE__)
require 'getFromApi.rb'

# Grab Requested [item] from hash and return ony that value
def findVmItem(t, item)
	t = t.upcase
	begin
		h = Hash[getFromApi('/api/v1/vmware/vm?is_relic=false&name='+t)]
		return h['data'][0][item]
	rescue StandardError => e
		return false
	end
end
