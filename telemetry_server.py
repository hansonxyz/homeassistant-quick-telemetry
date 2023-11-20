from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.parse as urlparse
from hashlib import md5
import paho.mqtt.client as mqtt
import json
import sys
import datetime

SECURITY_TOKEN_HASH = 'PUT_A_RANDOM_STRING_HERE'
MQTT_SERVER="127.0.0.1"
MQTT_PORT=1883

def send_to_mqtt(sensor_id, sensor_name, sensor_type, sensor_value):
    mqtt_broker = MQTT_SERVER
    mqtt_port = MQTT_PORT
    client = mqtt.Client()
    client.connect(mqtt_broker, mqtt_port, 60)

    config_topic = f"homeassistant/sensor/{sensor_id}/{sensor_id}/config"
    state_topic = f"{sensor_id}/{sensor_id}/state"

    # Define unit of measurement based on sensor type and set up the payload accordingly
    unit_of_measurement = None
    value_template = "{{ value }}"
    if sensor_type in ["disk_space", "temperature", "humidity", "percentage", "load", "number", "counter"]:
        unit_of_measurement = {
            "disk_space": "GB",
            "temperature": "°C",
            "humidity": "%",
            "percentage": "%",
            "load": "",
            "number": "",
            "counter": ""
        }[sensor_type]
        payload = float(sensor_value)  # Numeric types are sent as raw numbers
    elif sensor_type == "string":
        payload = json.dumps({"value": sensor_value})  # Strings are sent as a JSON object
        value_template = "{{ value_json.value }}"  # Use a value template to extract the string
    elif sensor_type == "date":
        payload = datetime.datetime.utcfromtimestamp(int(sensor_value)).isoformat() + 'Z'
        value_template = "{{ value }}"
        unit_of_measurement = None
        device_class = "timestamp"

    # Prepare the discovery payload
    discovery_payload = {
        "state_topic": state_topic,
        "name": sensor_name,
        "unique_id": sensor_id,
        "icon": "mdi:chart-bar",
        "expire_after": 1209600,  # 2 weeks
        "unit_of_measurement": unit_of_measurement,
        "value_template": value_template
    }

    # Add device class if applicable
    if sensor_type == "date":
        discovery_payload["device_class"] = device_class

    # Publish the discovery config message for Home Assistant
    client.publish(config_topic, json.dumps(discovery_payload), qos=1, retain=True)

    # Publish sensor data to MQTT
    client.publish(state_topic, payload, qos=1, retain=True)

    # Disconnect from MQTT broker
    client.disconnect()

class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.handle_request()

    def do_POST(self):
        self.handle_request()

    def handle_request(self):
        parsed_path = urlparse.urlparse(self.path)
        params = urlparse.parse_qs(parsed_path.query)

        # Check security token
        token = params.get('token', [None])[0]
        if not token or token != SECURITY_TOKEN_HASH:
            self.send_error(403, "Forbidden: Invalid security token - received "+token)
            return

        # Validate and send to MQTT
        try:
            sensor_id = params['sensor_id'][0]
            sensor_name = params['sensor_name'][0]
            sensor_type = params['sensor_type'][0]
            sensor_value = params['sensor_value'][0]

            send_to_mqtt(sensor_id, sensor_name, sensor_type, sensor_value)
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'ok')
        except Exception as e:
            self.send_error(500, f"Server Error: {e}")

def run(server_class=HTTPServer, handler_class=RequestHandler, port=80):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print(f'Server running on port {port}...')
    httpd.serve_forever()

if __name__ == "__main__":
    if len(sys.argv) == 2:
        run(port=int(sys.argv[1]))
    else:
        run()
