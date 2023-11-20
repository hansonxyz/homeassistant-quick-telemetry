#!/bin/bash

TOKEN="PUT_A_RANDOM_STRING_HERE" 
SERVER_URL="https://my_telemetry_server.my_domain.info"  

# Function to show help
show_help() {
cat << EOF
Usage: ${0##*/} SENSOR_ID SENSOR_NAME SENSOR_TYPE SENSOR_VALUE

Send sensor data to a Python HTTP server which publishes the data to MQTT.

Arguments:
  SENSOR_ID       Unique identifier for the sensor
  SENSOR_NAME     Descriptive name for the sensor
  SENSOR_TYPE     Type of the sensor data (disk_space, date, count, string, boolean, percentage, list, temperature, humidity, load, float, integer)
  SENSOR_VALUE    Value of the sensor data

Supported SENSOR_TYPE values and examples:
  disk_space      Amount of disk space available (e.g., 2048 for 2GB)
  date            Date and time in 'date' command format (e.g., "Sun Nov 19 02:08:08 AM CST 2023")
  count           An integer count (e.g., 42)
  string          A string value (e.g., "example string")
  boolean         A boolean value, true/false or on/off (e.g., true)
  percentage      A percentage value (e.g., 75.5 for 75.5%)
  list            A comma-separated list of values (e.g., "val1,val2,val3")
  temperature     Temperature value (e.g., 22.5 for 22.5°C)
  humidity        Humidity percentage (e.g., 60 for 60%)
  load            System load average as a floating point number (e.g., 1.05 for moderate load)
  float           Any floating point number (e.g., 23.42)
  integer         Any integer value (e.g., 157)

Examples:
  ${0##*/} sensor_disk "Disk C" disk_space 2048
  ${0##*/} sensor_date "Last Reboot" date "Sun Nov 19 02:08:08 AM CST 2023"
  ${0##*/} sensor_count "Login Attempts" count 42
  ${0##*/} sensor_temp "Outdoor Temp" temperature 22.5
  ${0##*/} sensor_hum "Indoor Humidity" humidity 60

EOF
}

# Exit if no arguments provided
if [ "$#" -ne 4 ]; then
    show_help
    exit 1
fi

SENSOR_ID="$1"
SENSOR_NAME="$2"
SENSOR_TYPE="$3"
SENSOR_VALUE="$4"

# Validate sensor type
declare -A valid_types=(
    [disk_space]="disk_space"
    [date]="date"
    [count]="counter"
    [string]="string"
    [boolean]="binary_sensor"
    [percentage]="percentage"
    [list]="list"
    [temperature]="temperature"
    [humidity]="humidity"
    [load]="number"
    [float]="number"
    [integer]="integer"
)

HA_SENSOR_TYPE=${valid_types[$SENSOR_TYPE]}

if [ -z "$HA_SENSOR_TYPE" ]; then
    echo "Error: Invalid sensor type '$SENSOR_TYPE'. Use --help for valid types."
    exit 1
fi

# Function to convert various date formats to Unix timestamp, if needed
convert_date_to_timestamp() {
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "$1"  # it's already a timestamp, return it as-is
    else
        # Use PHP to parse the date after removing the fractional seconds and replacing '+' with a space
        timestamp=$(php -r 'echo strtotime(preg_replace("/\.\d+/", "", str_replace("+", " ", $argv[1])));' "$1")
        if [[ -n "$timestamp" && "$timestamp" != "0" ]]; then
            echo "$timestamp"
        else
            echo "error: invalid date format $1" >&2
        fi
    fi
}

if [ "$SENSOR_TYPE" == "date" ]; then
    # Attempt to convert the date, pass through if it's already a timestamp
    NEW_SENSOR_VALUE=$(convert_date_to_timestamp "$SENSOR_VALUE")
    if [[ "$NEW_SENSOR_VALUE" == "error: invalid date format" ]]; then
        echo "$NEW_SENSOR_VALUE"
        exit 1
    else
        SENSOR_VALUE=$NEW_SENSOR_VALUE
    fi
fi


# Perform the curl request
HTTP_RESPONSE=$(curl -s -G -w "\n%{http_code}" \
  --data-urlencode "sensor_id=$SENSOR_ID" \
  --data-urlencode "sensor_name=$SENSOR_NAME" \
  --data-urlencode "sensor_type=$HA_SENSOR_TYPE" \
  --data-urlencode "sensor_value=$SENSOR_VALUE" \
  --data-urlencode "token=$TOKEN" \
  "$SERVER_URL")

# Separate the body and the status code
HTTP_BODY=$(echo "$HTTP_RESPONSE" | head -n -1)
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n1)

# Check if HTTP_STATUS is empty or not a number
if ! [[ "$HTTP_STATUS" =~ ^[0-9]+$ ]]; then
    echo "Error: No response or invalid response from server."
    exit 1
fi

# Check for HTTP status code
if [ "$HTTP_STATUS" -ne 200 ]; then
    echo "Error: Server responded with status $HTTP_STATUS"
    echo "Response body: $HTTP_BODY"
    exit 1
else
    echo ok
fi
