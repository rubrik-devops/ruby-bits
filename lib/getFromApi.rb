$LOAD_PATH.unshift File.expand_path('./', __FILE__)
require 'getToken.rb'

# Produce hash of VM Details based on search
def getFromApi(p)
  if Options.auth == 'token'
    (t,sv) = get_token
    conn = Faraday.new(:url => 'https://' + sv.sample(1)[0])
    conn.authorization :Bearer, t
  else
    (u,pw,sv) = get_token
    conn = Faraday.new(:url => 'https://' + sv.sample(1)[0])
    conn.basic_auth u, pw
    conn.headers['Authorization']
  end
  conn.ssl.verify = false
  response = conn.get p
  if response.status != 200
     msg = JSON.parse(response.body)['message']
     raise "Rubrik - Error (#{msg})"
  else
    o = JSON.parse(response.body)
    return o
  end
end
