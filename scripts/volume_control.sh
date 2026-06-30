#!/bin/bash

# Master (both channels)
TOPIC_SET="server/volume/set"
TOPIC_STATE="server/volume/state"

# Independent channels
TOPIC_LEFT_SET="server/volume/left/set"
TOPIC_LEFT_STATE="server/volume/left/state"
TOPIC_RIGHT_SET="server/volume/right/set"
TOPIC_RIGHT_STATE="server/volume/right/state"

# Per-channel mute (implemented as volume 0; the pre-mute level is restored)
TOPIC_LEFT_MUTE_SET="server/volume/left/mute/set"
TOPIC_LEFT_MUTE_STATE="server/volume/left/mute/state"
TOPIC_RIGHT_MUTE_SET="server/volume/right/mute/set"
TOPIC_RIGHT_MUTE_STATE="server/volume/right/mute/state"

# ALSA simple control to operate on. Must be a stereo control (with separate
# "Front Left"/"Front Right" channels) for independent left/right control.
# "Master" is mono on many codecs and cannot do per-channel. Override with
# $MIXER_CONTROL (e.g. "Speaker" or "Headphone") if PCM doesn't drive output.
CONTROL="${MIXER_CONTROL:-PCM}"

# Card the control lives on (amixer defaults to card 0 without this).
CARD="${MIXER_CARD:-0}"

# PCM to open in order to instantiate the control if it doesn't exist yet.
# softvol controls (e.g. "DownmixVol") are only created the first time their
# PCM is opened, so /etc/asound.conf must define this PCM with a matching
# control name. Ignored for controls the hardware already provides.
INIT_PCM="${INIT_PCM:-downmix}"

# --- ENVIRONMENT VARIABLES VALIDATION ---
# List of mandatory environment variables required by the script
REQUIRED_VARS=("BROKER_IP" "PORT" "MQTT_USER" "MQTT_PASS")
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

# Helper: publish a retained message.
pub() {
  mosquitto_pub -h "$BROKER_IP" -p "$PORT" -u "$MQTT_USER" -P "$MQTT_PASS" -t "$1" -m "$2" -r
}

# Helper: read the current volume of a given channel ("Front Left" / "Front Right").
# Falls back to the first reported percentage if the channel label is missing (mono).
get_channel() {
  local channel="$1" out line
  out=$(amixer -M -c "$CARD" sget "$CONTROL")
  # Prefer the requested channel's line; fall back to the first line that
  # reports a percentage (e.g. a single "Mono:" line on non-stereo devices).
  line=$(echo "$out" | grep -m 1 "$channel:")
  [ -z "$line" ] && line=$(echo "$out" | grep -m 1 -E '\[[0-9]+%\]')
  echo "$line" | grep -oE '[0-9]+%' | head -1 | tr -d '%'
}

# Helpers: set one channel while preserving the other (amixer uses L%,R%).
set_left()  { amixer -M -c "$CARD" sset "$CONTROL" "${1}%,$(get_channel 'Front Right')%" > /dev/null 2>&1; }
set_right() { amixer -M -c "$CARD" sset "$CONTROL" "$(get_channel 'Front Left')%,${1}%" > /dev/null 2>&1; }

# Helper: publish master, per-channel, and mute state (retained).
publish_state() {
  local left right master lmute rmute
  left=$(get_channel "Front Left");  left=${left:-0}
  right=$(get_channel "Front Right"); right=${right:-0}
  # Master mirrors the higher of the two channels (amixer's own convention).
  master=$(( left > right ? left : right ))
  # A channel at 0 is reported as muted.
  [ "$left" -eq 0 ]  && lmute="MUTED" || lmute="UNMUTED"
  [ "$right" -eq 0 ] && rmute="MUTED" || rmute="UNMUTED"

  pub "$TOPIC_LEFT_STATE"  "$left"
  pub "$TOPIC_RIGHT_STATE" "$right"
  pub "$TOPIC_STATE"       "$master"
  pub "$TOPIC_LEFT_MUTE_STATE"  "$lmute"
  pub "$TOPIC_RIGHT_MUTE_STATE" "$rmute"
}

# Ensure the mixer control exists before we touch it. softvol controls (e.g.
# "DownmixVol") are only created the first time their PCM is opened by a
# playback client. If the control is missing we open INIT_PCM for one second of
# silence to instantiate it, then verify. Hardware controls already present are
# left untouched (the first check returns immediately).
ensure_control() {
  amixer -c "$CARD" sget "$CONTROL" >/dev/null 2>&1 && return 0
  echo "Control '$CONTROL' not found on card $CARD; instantiating via PCM '$INIT_PCM'..." >&2
  # -t raw -f cd => S16_LE/44100/stereo silence; -d 1 caps /dev/zero at 1s.
  aplay -q -t raw -f cd -D "$INIT_PCM" -d 1 /dev/zero >/dev/null 2>&1 || true
  if amixer -c "$CARD" sget "$CONTROL" >/dev/null 2>&1; then
    echo "Control '$CONTROL' created on card $CARD." >&2
  else
    echo "Warning: could not create control '$CONTROL'. Ensure /etc/asound.conf defines a softvol PCM '$INIT_PCM' with control name '$CONTROL' on card $CARD." >&2
  fi
}
ensure_control

# Remember the last non-zero level per channel so unmute can restore it.
LEFT_PREMUTE=$(get_channel "Front Left");  [ "${LEFT_PREMUTE:-0}"  -gt 0 ] || LEFT_PREMUTE=50
RIGHT_PREMUTE=$(get_channel "Front Right"); [ "${RIGHT_PREMUTE:-0}" -gt 0 ] || RIGHT_PREMUTE=50

# 1. Publish initial state at service startup (retained).
publish_state

# 2. Listen on all set topics; -v prefixes each message with its topic.
mosquitto_sub -h "$BROKER_IP" -p "$PORT" -u "$MQTT_USER" -P "$MQTT_PASS" -v \
  -t "$TOPIC_SET" -t "$TOPIC_LEFT_SET" -t "$TOPIC_RIGHT_SET" \
  -t "$TOPIC_LEFT_MUTE_SET" -t "$TOPIC_RIGHT_MUTE_SET" | while read -r topic payload; do

  case "$topic" in
    "$TOPIC_SET")
      [[ "$payload" =~ ^[0-9]+$ ]] || continue
      amixer -M -c "$CARD" sset "$CONTROL" "${payload}%" > /dev/null 2>&1
      [ "$payload" -gt 0 ] && { LEFT_PREMUTE=$payload; RIGHT_PREMUTE=$payload; }
      ;;

    "$TOPIC_LEFT_SET")
      [[ "$payload" =~ ^[0-9]+$ ]] || continue
      set_left "$payload"
      [ "$payload" -gt 0 ] && LEFT_PREMUTE=$payload
      ;;

    "$TOPIC_RIGHT_SET")
      [[ "$payload" =~ ^[0-9]+$ ]] || continue
      set_right "$payload"
      [ "$payload" -gt 0 ] && RIGHT_PREMUTE=$payload
      ;;

    "$TOPIC_LEFT_MUTE_SET")
      cur=$(get_channel "Front Left"); cur=${cur:-0}
      case "${payload^^}" in
        MUTE)   [ "$cur" -gt 0 ] && LEFT_PREMUTE=$cur; set_left 0 ;;
        UNMUTE) set_left "$LEFT_PREMUTE" ;;
        TOGGLE) if [ "$cur" -eq 0 ]; then set_left "$LEFT_PREMUTE"; else LEFT_PREMUTE=$cur; set_left 0; fi ;;
        *) continue ;;
      esac
      ;;

    "$TOPIC_RIGHT_MUTE_SET")
      cur=$(get_channel "Front Right"); cur=${cur:-0}
      case "${payload^^}" in
        MUTE)   [ "$cur" -gt 0 ] && RIGHT_PREMUTE=$cur; set_right 0 ;;
        UNMUTE) set_right "$RIGHT_PREMUTE" ;;
        TOGGLE) if [ "$cur" -eq 0 ]; then set_right "$RIGHT_PREMUTE"; else RIGHT_PREMUTE=$cur; set_right 0; fi ;;
        *) continue ;;
      esac
      ;;
  esac

  # 3. Publish the updated state (retained) after any change.
  publish_state

done
