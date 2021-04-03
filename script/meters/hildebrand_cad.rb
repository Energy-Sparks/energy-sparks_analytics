require 'mqtt'

# Subscribe example

puts "login = #{ENV['GLO_LOGIN']}, password = #{ENV['GLO_PASSWORD']}"

device = 'SMART/HILD/'

MQTT::Client.connect(
  :host => 'glowmqtt.energyhive.com',
  :username => ENV['GLO_LOGIN'],
  :password => ENV['GLO_PASSWORD']
)
MQTT::Client.connect('glowmqtt.energyhive.com') do |c|
  # If you pass a block to the get method, then it will loop
  puts "Got here"
  puts c
  c.get('test') do |topic,message|
    puts "#{topic}: #{message}"
  end
end
