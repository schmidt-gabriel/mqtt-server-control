#!/bin/bash

# --- SYSTEM MONITORING SCRIPT ---
# Monitors CPU, Memory, CPU Temperature, CPU Power, and Disk Usage
# Publishes data to MQTT topics

# MQTT Topics
TOPIC_CPU="server/system/cpu"
TOPIC_MEMORY="server/system/memory"
TOPIC_CPU_TEMP="server/system/cpu_temp"
TOPIC_CPU_POWER="server/system/cpu_power"
TOPIC_DISK="server/system/disk"

# --- ENVIRONMENT VARIABLES VALIDATION ---
REQUIRED_VARS=("BROKER_IP" "PORT" "USER" "PASS")
ERROR=0

for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var}" ]]; then
    echo "Critical Error: Environment variable \$$var is not set!" >&2
    ERROR=1
  fi
done

if [ $ERROR -eq 1 ]; then
  echo "Please export all required environment variables before running this script." >&2
  exit 1
fi
# ----------------------------------------

# Function to publish to MQTT
publish_metric() {
  local topic=$1
  local value=$2
  mosquitto_pub -h "$BROKER_IP" -p "$PORT" -u "$USER" -P "$PASS" -t "$topic" -m "$value" -r
}

# Function to get CPU usage percentage
get_cpu_usage() {
  top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
}

# Function to get Memory usage percentage
get_memory_usage() {
  free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}'
}

# Function to get CPU temperature
get_cpu_temperature() {
  if command -v sensors &> /dev/null; then
    sensors | grep "Core 0" | head -1 | awk '{print $3}' | tr -d '+°C'
  else
    echo "N/A"
  fi
}

# Function to get CPU power consumption
get_cpu_power() {
  if command -v turbostat &> /dev/null; then
    turbostat --quiet --show PkgWatt -n 1 2>/dev/null | tail -1 | awk '{print $1}'
  else
    echo "N/A"
  fi
}

# Function to get Disk usage percentage
get_disk_usage() {
  df / | tail -1 | awk '{print $5}' | tr -d '%'
}

# Main monitoring loop
echo "Starting system monitoring service..."

while true; do
  # Collect metrics
  CPU_USAGE=$(get_cpu_usage)
  MEMORY_USAGE=$(get_memory_usage)
  CPU_TEMP=$(get_cpu_temperature)
  CPU_POWER=$(get_cpu_power)
  DISK_USAGE=$(get_disk_usage)

  # Publish metrics
  publish_metric "$TOPIC_CPU" "$CPU_USAGE"
  publish_metric "$TOPIC_MEMORY" "$MEMORY_USAGE"
  publish_metric "$TOPIC_CPU_TEMP" "$CPU_TEMP"
  publish_metric "$TOPIC_CPU_POWER" "$CPU_POWER"
  publish_metric "$TOPIC_DISK" "$DISK_USAGE"

  # Wait 5 seconds before next update
  sleep 5
done
