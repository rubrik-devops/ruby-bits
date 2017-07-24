$LOAD_PATH.unshift File.expand_path('./', __FILE__)
require 'getToken.rb'

def getFromApi(p)
  unless @token.nil?
    t = @token
    sv = @rubrikhost
  else
    (t,sv) = get_token
  end
  c = Faraday.new(:url => 'https://' + sv)
  c.ssl.verify = false
  c.authorization :Bearer, t
  r = c.get p
  if r.status != 200
     msg = JSON.parse(r.body)['message']
     raise "Rubrik - Error (#{msg})"
  else
    o = JSON.parse(r.body)
    return o
  end
end
