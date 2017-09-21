require 'net/https'
require 'pp'
require 'uri'

def setToApi(server,endpoint,l,type)
  endpoint = URI.encode(endpoint)
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
  response = conn.public_send(type) do |req|
    req.url endpoint
    req.headers['Content-Type'] = 'application/json'
    req.body  = l.to_json
  end
  if response.status !~ /202|200/
    return response.body
  end
end
