require 'digest'
require 'net/http'
require 'json'
require 'uri'
require 'tzinfo'

# working CURL:
# curl --verbose --header "Authorization: 1a9ff6bf-3512-4739-ae96-d912cde23a6e" https://sandboxapi.data.n3rgy.com/1234567891034/electricity/consumption/1?start=201301021600&end=201301021830&granularity=halfhour

if false
  puts "UK Carbon request===================================================="
  url = 'https://api.carbonintensity.org.uk/generation'
  response = Net::HTTP.get(URI(url))
  data = JSON.parse(response)
  puts data
end

if false
  puts "Request without Authorisation=========================================="
  url = 'https://sandboxapi.data.n3rgy.com/1234567891034/electricity/consumption/1?start=201301021600&end=201301021830&granularity=halfhour'
  # https://stackoverflow.com/questions/33770326/ruby-http-sending-api-key-basic-auth
  uri = URI(url)
  puts "host: #{uri.host} #{uri.port} scheme #{uri.scheme} info #{uri.to_s}"
  response = Net::HTTP.get(uri)
  puts "get_print #{Net::HTTP.get_print(uri)}"
  data = JSON.parse(response)
  puts data
end

puts "Request with Authorisation 1 =========================================="
url = 'https://sandboxapi.data.n3rgy.com/1234567891034/electricity/consumption/1?start=201301021600&end=201301021830&granularity=halfhour'
uri = URI(url)
http = Net::HTTP.new(uri.host, uri.port)
http.set_debug_output($stdout)
request = Net::HTTP::Get.new(uri.request_uri)
request['Authorization'] = '1a9ff6bf-3512-4739-ae96-d912cde23a6e'
x = http.request(request)
x.each_header do |key, value|
  p "#{key} => #{value}"
end

exit
puts "Got here: #{x.inspect}"
puts JSON.parse(request)
exit
puts "Request with Authorisation 2 =========================================="
http = Net::HTTP.new(uri)
request = Net::HTTP::Get.new(uri)
request['Authorization'] = '1a9ff6bf-3512-4739-ae96-d912cde23a6e'
http.request(uri)
exit
http = Net::HTTP.new(uri)
request = Net::HTTP::Get.new(uri.request_uri)
# request['Authorization'] = '1a9ff6bf-3512-4739-ae96-d912cde23a6e'

x = http.request(request)
puts x.inspect
exit
data = JSON.parse(request)

puts data
