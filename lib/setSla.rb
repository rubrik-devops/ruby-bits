require 'setToApi.rb'

def setSla(mId,id)
    o = setToApi('rubrik','/api/v1/vmware/vm/' + mId ,{ "configuredSlaDomainId" => "#{id}"},"patch")
    return o
end
