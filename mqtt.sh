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

# --- SPEAKER TEST ---
# Check if ENABLE_SPEAKER_TEST is set and true
if [[ "${ENABLE_SPEAKER_TEST}" == "true" ]]; then
  SPEAKER_TEST_SCRIPT="${SCRIPT_DIR}/scripts/speaker_test.sh"
  echo "ENABLE_SPEAKER_TEST is enabled. Starting speaker test listener..."

  # Make it executable and run it in background
  chmod +x "${SPEAKER_TEST_SCRIPT}"
  "${SPEAKER_TEST_SCRIPT}" &
fi

# Keep the script running
wait
