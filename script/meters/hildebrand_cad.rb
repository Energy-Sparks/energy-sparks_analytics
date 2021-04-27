require 'mqtt'
require 'json'
require 'date'
require 'csv'

def decode(message)
  dt = DateTime.now.strftime('%Y-%m-%d %H:%M:%S')

  return { dt: dt, w: 0.0, kwh: 0.0, status: 'nil message' } if message.nil?

  status = message['pan']['status']

  return { dt: dt, w: 0.0, kwh: 0.0, status: status } if status == 'rejoin_failed'

  begin
    w = message['elecMtr']['0702']['04']['00'].to_i(16).to_f
    w = w - 0xFFFFFFFF - 1 if w > 0x80000000 # exporting electricity

    kwh = message['elecMtr']['0702']['04']['01'].to_i(16).to_f
    m = message['elecMtr']['0702']['03']['01'].to_i(16).to_f
    d = message['elecMtr']['0702']['03']['02'].to_i(16).to_f
    kwh *= m /d

    {
      dt:     dt,
      w:      w,
      kwh:    kwh,
      status: status
    }
  rescue => e
    { dt: dt, w: 0.0, kwh: 0.0, status: e.message }
  end
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
    puts data
  end
end
