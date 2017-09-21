$LOAD_PATH.unshift File.expand_path('./', __FILE__)
require 'getToken.rb'

# Produce hash of VM Details based on search
def getFromApi(server,p)
  if Options.auth == 'token'
    (t,sv) = get_token(server)
    conn = Faraday.new(:url => 'https://' + sv.sample(1)[0])
    conn.authorization :Bearer, t
  else
    (u,pw,sv) = get_token(server)
    conn = Faraday.new(:url => 'https://' + sv.sample(1)[0])
    conn.basic_auth u, pw
    conn.headers['Authorization']
  end
  conn.ssl.verify = false
  response = conn.get p
  if response.status != 200
     puts response.body
     msg = JSON.parse(response.body)['message']
     raise "Rubrik - Error (#{msg})"
  else
    o = JSON.parse(response.body)
    return o
  end
end

def vmwareFromApi(server,p)
  (u,pw,sv) = get_token(server)
  conn = Faraday.new(:url => 'https://' + sv.sample(1)[0])     
  conn.basic_auth u, pw
  conn.ssl.verify = false
  conn.headers['vmware-api-session-id'] = ''
  response=conn.post '/com/vmware/cis/session'
  puts response.status
end
