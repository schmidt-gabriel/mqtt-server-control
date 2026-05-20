#!/bin/bash

TOPIC_SET="server/volume/set"
TOPIC_STATE="server/volume/state"

# --- ENVIRONMENT VARIABLES VALIDATION ---
# List of mandatory environment variables required by the script
REQUIRED_VARS=("BROKER_IP" "PORT" "USER" "PASS")
ERROR=0

for var in "${REQUIRED_VARS[@]}"; do
  # Indirect expansion (${!var}) checks the actual value of the variable name stored in 'var'
  if [[ -z "${!var}" ]]; then
    echo "Critical Error: Environment variable \$$var is not set!" >&2
    ERROR=1
  fi
done

# If any variable is missing, abort execution immediately
if [ $ERROR -eq 1 ]; then
  echo "Please export all required environment variables before running this script." >&2
  exit 1
fi
# ----------------------------------------

# 1. Read the actual current volume at service startup
START_VOLUME=$(amixer -M sget Master | grep -m 1 -oE '[0-9]+%' | tr -d '%')

# 2. Publish initial state WITH THE RETAIN FLAG (-r)
mosquitto_pub -h "$BROKER_IP" -p "$PORT" -u "$USER" -P "$PASS" -t "$TOPIC_STATE" -m "$START_VOLUME" -r

mosquitto_sub -h "$BROKER_IP" -p "$PORT" -u "$USER" -P "$PASS" -t "$TOPIC_SET" | while read -r volume; do
  if [[ "$volume" =~ ^[0-9]+$ ]]; then

    amixer -M sset Master "${volume}%" > /dev/null 2>&1
    REAL_VOLUME=$(amixer -M sget Master | grep -m 1 -oE '[0-9]+%' | tr -d '%')

    # 3. Publish the updated state WITH THE RETAIN FLAG (-r)
    mosquitto_pub -h "$BROKER_IP" -p "$PORT" -u "$USER" -P "$PASS" -t "$TOPIC_STATE" -m "$REAL_VOLUME" -r

  fi
done
