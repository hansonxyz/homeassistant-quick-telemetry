#!/bin/bash

# Function to get CPU load as a percentage
get_cpu_load() {
    awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else {printf "%.2f", (($2+$4)-u1) * 100 / (t-t1);}}' \
    <(grep 'cpu ' /proc/stat) <(sleep 1; grep 'cpu ' /proc/stat)
}

# Function to get the creation date of the oldest directory
get_oldest_directory_date() {
    find "$1" -mindepth 1 -maxdepth 1 -type d -printf '%T+ %p\n' | sort | head -n 1 | cut -d' ' -f1
}

get_system_load() {
    cut -d' ' -f2 < /proc/loadavg
}

get_disk_free_space() {
    local used_space=$(df --output=pcent "$1" | tail -n 1 | tr -dc '0-9')
    local free_space=$((100 - used_space))
    echo "$free_space"
}

get_disk_free_gb() {
    local avail_blocks=$(df --output=avail "$1" | tail -n 1)
    local free_gb=$((avail_blocks / (1024 * 1024)))  # Convert from 1K blocks to GB
    echo "$free_gb"
}


# Variables for sensor names
HOSTNAME="MyHostName"

CPU_SENSOR_NAME="${HOSTNAME}_CPU_Load"
SYSTEM_LOAD_NAME="${HOSTNAME}_System_Load"
DISK_ROOT_SENSOR_NAME="${HOSTNAME}_Disk_Free_Root"
DISK_ROOT_GB_SENSOR_NAME="${HOSTNAME}_Disk_Free_Gb_Root"

# Get the data
CPU_LOAD=$(get_cpu_load)
SYSTEM_LOAD=$(get_system_load)
DISK_FREE_ROOT=$(get_disk_free_space '/')
DISK_FREE_GB_ROOT=$(get_disk_free_gb '/')

# Call the telemetry.sh script with the gathered data
telemetry_client.sh "$CPU_SENSOR_NAME" "${HOSTNAME}: CPU Load" percentage "$CPU_LOAD"
telemetry_client.sh "$SYSTEM_LOAD_NAME" "${HOSTNAME}: System Load" float "$SYSTEM_LOAD"
telemetry_client.sh "$DISK_ROOT_SENSOR_NAME" "${HOSTNAME}: Disk Free Root" percentage "$DISK_FREE_ROOT"
telemetry_client.sh "$DISK_ROOT_GB_SENSOR_NAME" "${HOSTNAME}: Disk Free GB Root" disk_space "$DISK_FREE_GB_ROOT"
