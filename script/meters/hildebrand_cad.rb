require 'mqtt'
require 'require_all'
require_relative '../../lib/dashboard.rb'

# Subscribe example

puts "login = #{ENV['GLO_LOGIN']}, password = #{ENV['GLO_PASSWORD']}"

device = 'SMART/HILD/' + ENV['GLO_DEVICE_MAC_ADDRESS']

MQTT::Client.connect(
  :host => 'glowmqtt.energyhive.com',
  :username => ENV['GLO_LOGIN'],
  :password => ENV['GLO_PASSWORD']
)
MQTT::Client.connect('glowmqtt.energyhive.com') do |client|
  # If you pass a block to the get method, then it will loop
  puts "Got here #{device}"
  puts client
  ap client.subscribe(device)
  client.get do |topic, message|
    puts "#{topic}: #{message}"
  end
end
