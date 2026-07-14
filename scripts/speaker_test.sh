#!/bin/bash

# Speaker test: plays a test tone on the LEFT or RIGHT physical channel so you
# can confirm each speaker works and is wired to the correct side.
#
# The tone is sent straight to the raw card device (hw:CARD,0) via speaker-test
# with a single channel selected (-s 1 = Front Left, -s 2 = Front Right). This
# deliberately BYPASSES the /etc/asound.conf downmix (which sums L+R into both
# channels) and the softvol volume stage, so a single physical speaker is
# exercised in isolation at the hardware output level.

# Command topic: publish LEFT | RIGHT | SEQUENCE (case-insensitive).
#   LEFT     -> tone on the left speaker only
#   RIGHT    -> tone on the right speaker only
#   SEQUENCE -> left, short gap, then right (find swapped wiring in one shot)
TOPIC_TEST_SET="server/speaker/test/set"
# State topic (retained): IDLE | TESTING_LEFT | TESTING_RIGHT | ERROR
TOPIC_TEST_STATE="server/speaker/test/state"

# Card the analog output lives on (matches volume_control.sh's MIXER_CARD).
CARD="${MIXER_CARD:-0}"
# Raw playback device to open. Direct hw: access isolates a single channel and
# skips the downmix; override if your output is not subdevice 0.
TEST_DEVICE="${TEST_DEVICE:-hw:${CARD},0}"
# Sine frequency (Hz) and how long each channel plays (seconds).
TEST_FREQ="${TEST_FREQ:-440}"
TEST_DURATION="${TEST_DURATION:-3}"
# Gap between channels in SEQUENCE mode (seconds).
TEST_GAP="${TEST_GAP:-1}"

# --- ENVIRONMENT VARIABLES VALIDATION ---
REQUIRED_VARS=("BROKER_IP" "PORT" "MQTT_USER" "MQTT_PASS")
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

# Helper: publish a retained message.
pub() {
  mosquitto_pub -h "$BROKER_IP" -p "$PORT" -u "$MQTT_USER" -P "$MQTT_PASS" -t "$1" -m "$2" -r
}

# Play a bounded sine on a single channel. $1 = channel number (1=L, 2=R).
# speaker-test loops forever with -s and no -l, so `timeout` caps the duration.
# Returns non-zero if the device is busy (e.g. shairport is streaming) or fails.
play_channel() {
  local ch="$1"
  timeout "$TEST_DURATION" \
    speaker-test -D "$TEST_DEVICE" -c 2 -t sine -f "$TEST_FREQ" -s "$ch" \
    >/dev/null 2>&1
  # timeout exits 124 when it stops a still-running (i.e. successful) playback.
  local rc=$?
  [ "$rc" -eq 124 ] && rc=0
  return "$rc"
}

# Run one side and report state; leaves state on ERROR if playback failed.
test_side() {
  local ch="$1" label="$2"
  pub "$TOPIC_TEST_STATE" "TESTING_${label}"
  if ! play_channel "$ch"; then
    echo "speaker-test failed on $TEST_DEVICE channel $ch (device busy or unavailable)." >&2
    pub "$TOPIC_TEST_STATE" "ERROR"
    return 1
  fi
  return 0
}

# Publish initial idle state (retained).
pub "$TOPIC_TEST_STATE" "IDLE"

# Listen for test requests. Processing is synchronous: a test finishes before
# the next message is handled, so overlapping requests can't fight for the card.
mosquitto_sub -h "$BROKER_IP" -p "$PORT" -u "$MQTT_USER" -P "$MQTT_PASS" -v \
  -t "$TOPIC_TEST_SET" | while read -r _topic payload; do

  case "${payload^^}" in
    LEFT)
      test_side 1 "LEFT" && pub "$TOPIC_TEST_STATE" "IDLE"
      ;;
    RIGHT)
      test_side 2 "RIGHT" && pub "$TOPIC_TEST_STATE" "IDLE"
      ;;
    SEQUENCE|BOTH)
      if test_side 1 "LEFT"; then
        sleep "$TEST_GAP"
        test_side 2 "RIGHT" && pub "$TOPIC_TEST_STATE" "IDLE"
      fi
      ;;
    *)
      echo "Ignoring unknown speaker-test payload: '$payload' (expected LEFT|RIGHT|SEQUENCE)." >&2
      ;;
  esac

done
