require 'mqtt'
require 'json'
require 'date'
require 'csv'

def decode(message)
  w = message['elecMtr']['0702']['04']['00'].to_i(16).to_f
  w -= 16777216 if w > 10000000

  kwh = message['elecMtr']['0702']['04']['01'].to_i(16).to_f
  m = message['elecMtr']['0702']['03']['01'].to_i(16).to_f
  d = message['elecMtr']['0702']['03']['02'].to_i(16).to_f
  kwh *= m /d

  {
    d:    DateTime.now.strftime('%Y-%m-%d %H:%M:%S'),
    w:    w,
    kwh:  kwh
  }
end

def save_to_csv(data)
  CSV.open('./cad_device_data.csv', 'a') do |csv|
    csv << data.values
  end
end

MQTT::Client.connect(
  :host => 'glowmqtt.energyhive.com',
  :username => ENV['GLO_LOGIN'],
  :password => ENV['GLO_PASSWORD']
) do |client|
  client.subscribe('SMART/HILD/' + ENV['GLO_DEVICE_MAC_ADDRESS'])
  client.get do |_topic, message|
    data = decode(JSON.parse(message))
    save_to_csv(data)
    print '.'
  end
end
