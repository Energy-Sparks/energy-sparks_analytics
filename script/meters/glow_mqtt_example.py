# PURPOSE: To input Smart Meter data into emoncms (data obtained via a Hildebrand Glow Stick https://www.hildebrand.co.uk/our-products/glow-stick-wifi-cad/ )

# With due acknowledgement to ndfred - a contributor to the Glowmarkt forum
# https://gist.github.com/ndfred/b373eeafc4f5b0870c1b8857041289a9

# Developed and tested on a Raspberry Pi running the Oct 2019 emon image updated to ver 10.2.6

# HOW TO ...

# It's simpler to set up the primary INPUT(tag) first before the script is run. The script can then just refer to this INPUT(tag)

# Start by doing the following in an SSH terminal ...

# Install mosquitto-clients with: sudo apt-get install mosquitto-clients

# Then enter: node="Glow Stick"  # The chosen INPUT(tag) name
# Check by doing: echo $node

# Then enter:  curl --data "node=node&apikey=????????????" "http://127.0.0.1/input/post"    # use appropriate apikey

# Ignore the message about the request containing no data
# The INPUT(tag) (Glow Stick) will have been created but it will not be visible on the Inputs webpage until some input data is subsequently posted

# Then copy this script file to  /home/pi  and make it executable with:  chmod +x /home/pi/glow.py    # using the chosen script name

# Run the script with: /usr/bin/python3 /home/pi/glow.py    # using the chosen script name

# All being well, Smart Meter data will appear in emoncms webpage Inputs and be refreshed every 10 secs - Power Now(W) and Daily & CUM Energy(kWh)

# Create FEEDS using Log to Feed and add UNITS (pencil drop-down) to each

# FINALLY ONCE THE SCRIPT RUNS OK: Create the glow.service and enable it so the script runs on boot up as follows:
# Do: CTRL-C to stop the script then - Do: sudo nano /etc/systemd/system/glow.service  and copy & paste in the following (using the chosen script name) ...

"""

[Unit]
Description=Glow Stick service
After=network.target
After=mosquitto.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=pi
ExecStart=/usr/bin/python3 /home/pi/glow.py

[Install]
WantedBy=multi-user.target

"""
# Then save & exit and to ensure the glow.service runs on boot up - Do:  sudo systemctl enable glow.service

# AS A VERY LAST CHECK - Do: sudo reboot then SSH in again and check the service is active with:  systemctl status glow.service

# Finally close the SSH terminal. The script/service will continue to run surviving any future reboots

# ===============================================================================

import datetime
import logging
import json
import paho.mqtt.client as mqtt    # paho-mqtt is already installed in emon
import requests 
import os   

# Glow Stick configuration
GLOW_LOGIN = os.environ.get('GLO_LOGIN')
GLOW_PASSWORD = os.environ.get('GLO_PASSWORD')
GLOW_DEVICE_ID = os.environ.get('GLO_DEVICE_MAC_ADDRESS')

print(GLOW_LOGIN)
print(GLOW_PASSWORD)
print(GLOW_DEVICE_ID)


# Emoncms server configuration
emoncms_apikey = "your apikey"
server = "http://127.0.0.1"
node = "Glow Stick"  # Name of the Input(tag) created to receive the INPUT data 

# Name each of the data inputs associated with the newly created Input(tag)
di1 = "Power Now"      # ref E_NOW below
di2 = "Daily Energy"   # ref E_DAY below
di3 = "CUM Energy"     # ref E_METER below

# End of User inputs section ===============

def on_connect(client, _userdata, _flags, result_code):
    print("Got here")
    if result_code != mqtt.MQTT_ERR_SUCCESS:
        print("Error 1")
        logging.error("Error connecting: %d", result_code)
        return

    result_code, _message_id = client.subscribe("SMART/HILD/" + GLOW_DEVICE_ID)

    if result_code != mqtt.MQTT_ERR_SUCCESS:
        print("Error 1")
        logging.error("Couldn't subscribe: %d", result_code)
        return

    print("Got here all working")
    logging.info("Connected and subscribed")

def on_message(_client, _userdata, message):
    print("Received a message")
    payload = json.loads(message.payload)
    current_time = datetime.datetime.now().strftime("%H:%M:%S")
	
    electricity_consumption = int(payload["elecMtr"]["0702"]["04"]["00"], 16)

    if electricity_consumption > 10000000: electricity_consumption = electricity_consumption - 16777216 # Added JB - hex FFFFFF is 16777215 in unsigned 24 bit but -1 in signed 24 bit
    E_NOW = electricity_consumption   # Added JB

    electricity_daily_consumption = int(payload["elecMtr"]["0702"]["04"]["01"], 16)
	
    # electricity_weekly_consumption = int(payload["elecMtr"]["0702"]["04"]["30"], 16)  # Data not provided by GLOW
    # electricity_monthly_consumption = int(payload["elecMtr"]["0702"]["04"]["40"], 16)  # Data not provided by GLOW
    electricity_multiplier = int(payload["elecMtr"]["0702"]["03"]["01"], 16)
    electricity_divisor = int(payload["elecMtr"]["0702"]["03"]["02"], 16)
    electricity_meter = int(payload["elecMtr"]["0702"]["00"]["00"], 16)

    electricity_daily_consumption = electricity_daily_consumption * electricity_multiplier / electricity_divisor
    E_DAY = electricity_daily_consumption     # Added JB
	
    # electricity_weekly_consumption = electricity_weekly_consumption * electricity_multiplier / electricity_divisor
    # electricity_monthly_consumption = electricity_monthly_consumption * electricity_multiplier / electricity_divisor
    electricity_meter = electricity_meter * electricity_multiplier / electricity_divisor
    E_METER = electricity_meter     # Added JB                               
	
    assert(int(payload["elecMtr"]["0702"]["03"]["00"], 16) == 0) # kWh
    
    logging.info("Reading at %s", current_time)
    logging.info("electricity consumption: %dW", electricity_consumption)
    logging.info("daily electricity consumption: %.3fkWh", electricity_daily_consumption)
    # logging.info("* weekly electricity consumption: %.3fkWh", electricity_weekly_consumption)
    # logging.info("* monthly electricity consumption: %.3fkWh", electricity_monthly_consumption)
    logging.info("electricity meter: %.3fkWh", electricity_meter)
    
    # logging.info("Full payload: %s", json.dumps(payload, indent=2))   # Don't need this info printed
	                    	
    data1 = E_NOW
    data2 = E_DAY
    data3 = E_METER

    # Send data to emoncms

    dev_data = {di1: data1, di2: data2, di3: data3}

    data = {
      'node': node,
      'data': json.dumps (dev_data),
      'apikey': emoncms_apikey
    }

    # response = requests.post(server+"/input/post", data=data)
	
def loop():
    logging.basicConfig(level=logging.DEBUG, format='%(message)s')
    client = mqtt.Client()
    client.username_pw_set(GLOW_LOGIN, GLOW_PASSWORD)
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect("glowmqtt.energyhive.com")
    client.loop_forever()

if __name__ == "__main__":
    loop()

