#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- VOLUME CONTROL ---
# Check if ENABLE_VOLUME_CONTROL is set and true
if [[ "${ENABLE_VOLUME_CONTROL}" == "true" ]]; then
  VOLUME_CONTROL_SCRIPT="${SCRIPT_DIR}/scripts/volume_control.sh"
  echo "ENABLE_VOLUME_CONTROL is enabled. Starting volume control..."
  
  # Make it executable and run it in background
  chmod +x "${VOLUME_CONTROL_SCRIPT}"
  "${VOLUME_CONTROL_SCRIPT}" &
fi

# --- SYSTEM MONITORING ---
# Check if ENABLE_SYSTEM_MONITOR is set and true
if [[ "${ENABLE_SYSTEM_MONITOR}" == "true" ]]; then
  SYSTEM_MONITOR_SCRIPT="${SCRIPT_DIR}/scripts/system_monitor.sh"
  echo "ENABLE_SYSTEM_MONITOR is enabled. Starting system monitoring..."
  
  # Make it executable and run it in background
  chmod +x "${SYSTEM_MONITOR_SCRIPT}"
  "${SYSTEM_MONITOR_SCRIPT}" &
fi

# Keep the script running
wait
