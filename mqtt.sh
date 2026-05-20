#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- VOLUME CONTROL ---
# Check if ENABLE_VOLUME_CONTROL is set and true
if [[ "${ENABLE_VOLUME_CONTROL}" == "true" ]]; then
  echo "ENABLE_VOLUME_CONTROL is enabled. Starting volume control..."
  
  VOLUME_CONTROL_SCRIPT="${SCRIPT_DIR}/volume_control.sh"
  
  # Make it executable and run it in background
  chmod +x "${VOLUME_CONTROL_SCRIPT}"
  "${VOLUME_CONTROL_SCRIPT}" &
else
  echo "ENABLE_VOLUME_CONTROL is disabled or not set. Skipping volume control."
fi

# --- SYSTEM MONITORING ---
# Check if ENABLE_SYSTEM_MONITOR is set and true
if [[ "${ENABLE_SYSTEM_MONITOR}" == "true" ]]; then
  echo "ENABLE_SYSTEM_MONITOR is enabled. Starting system monitoring..."
  
  SYSTEM_MONITOR_SCRIPT="${SCRIPT_DIR}/system_monitor.sh"
  
  # Make it executable and run it in background
  chmod +x "${SYSTEM_MONITOR_SCRIPT}"
  "${SYSTEM_MONITOR_SCRIPT}" &
else
  echo "ENABLE_SYSTEM_MONITOR is disabled or not set. Skipping system monitoring."
fi

# Keep the script running
wait
