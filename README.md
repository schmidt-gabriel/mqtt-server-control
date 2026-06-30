# MQTT Server Control

A Bash-based service for controlling system volume via MQTT topics.

## Features

-  **Volume Control**: Remote volume management via MQTT topics
-  **MQTT Integration**: Publish volume state to MQTT broker with retain flag for persistence
-  **Docker Support**: Easily deployable as a Docker container
-  **Configurable**: Enable/disable features via environment variables
-  **Error Handling**: Comprehensive validation and graceful degradation

## Requirements

- Bash 4.0+
- `mosquitto_pub` and `mosquitto_sub` (MQTT client tools)
- `amixer` (for volume control)

## Installation

### Prerequisites

1. An active MQTT broker (Mosquitto or similar)
2. Bash environment with required utilities

### Quick Start

1. Clone the repository:
```bash
git clone https://github.com/schmidt-gabriel/mqtt-server-control.git
cd mqtt-server-control
```

2. Make scripts executable:
```bash
chmod +x *.sh
```

3. Set environment variables:
```bash
export BROKER_IP="192.168.1.100"
export PORT="1883"
export MQTT_USER="mqtt_user"
export MQTT_PASS="mqtt_password"
export ENABLE_VOLUME_CONTROL="true"
```

4. Run the main script:
```bash
./mqtt.sh
```

### Docker Deployment

Build the Docker image:
```bash
docker build -t mqtt-server-control .
```

Run with environment variables:
```bash
docker run -d \
  -e BROKER_IP="192.168.1.100" \
  -e PORT="1883" \
  -e MQTT_USER="mqtt_user" \
  -e MQTT_PASS="mqtt_password" \
  -e ENABLE_VOLUME_CONTROL="true" \
  mqtt-server-control
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BROKER_IP` | Yes | - | MQTT broker IP address |
| `PORT` | Yes | - | MQTT broker port |
| `MQTT_USER` | Yes | - | MQTT username |
| `MQTT_PASS` | Yes | - | MQTT password |
| `ENABLE_VOLUME_CONTROL` | No | false | Enable volume control service |
| `MIXER_CONTROL` | No | `PCM` | ALSA simple control to drive. Must be **stereo** (separate Front Left/Front Right channels) for per-channel control. `Master` is often mono. Use `amixer scontrols` / `amixer sget <name>` to inspect; set to `Speaker` or `Headphone` if `PCM` doesn't affect your output. |
| `MIXER_CARD` | No | `0` | ALSA card index the control lives on (`amixer -c <n>`). Find it with `cat /proc/asound/cards`. |
| `INIT_PCM` | No | `downmix` | PCM opened at startup to instantiate `MIXER_CONTROL` if it doesn't exist yet (see "Software volume controls" below). |

## MQTT Topics

### Volume Control Topics
```
server/volume/set           → Set volume on both channels (0-100)
server/volume/state         → Current master level (higher of the two channels)

server/volume/left/set      → Set left channel only (0-100)
server/volume/left/state    → Current left channel level

server/volume/right/set     → Set right channel only (0-100)
server/volume/right/state   → Current right channel level

server/volume/left/mute/set    → Mute left   (MUTE | UNMUTE | TOGGLE)
server/volume/left/mute/state  → Left mute state  (MUTED | UNMUTED)
server/volume/right/mute/set   → Mute right  (MUTE | UNMUTE | TOGGLE)
server/volume/right/mute/state → Right mute state (MUTED | UNMUTED)
```

Setting one channel keeps the other channel unchanged. The master topic
(`server/volume/set`) sets both channels to the same level.

Mute is implemented by setting the channel volume to `0`; the pre-mute level
is remembered and restored on unmute. A channel sitting at `0%` is reported as
`MUTED`.

All state topics are published with the **retain flag** (`-r`) to maintain state after reconnection.

### Software volume controls (`DownmixVol`)

If your hardware has no usable stereo control, create a software one with ALSA's
`softvol` plugin instead. A `softvol` control (commonly named `DownmixVol`) is
not a hardware mixer; it is created the **first time its PCM is opened** by a
playback client, after which it lives in the card's control list until reboot.

That is why `amixer: Unable to find simple control 'DownmixVol',0` appears at a
cold start: nothing has opened the PCM yet. On startup `volume_control.sh` now
checks for `MIXER_CONTROL` and, if missing, opens `INIT_PCM` for one second of
silence (`aplay`) to instantiate it. This requires an `/etc/asound.conf` that
defines `INIT_PCM` as a `softvol` PCM with `control.name` equal to
`MIXER_CONTROL`; a ready-to-use example lives at `homelab/Shairport/asound.conf`.
Mount the same file into this container so both the player and the bridge share
one control.

## Files

### mqtt.sh
Main entry point script that orchestrates the services.
- Validates environment variables
- Starts volume control service (if enabled)
- Manages background processes

### volume_control.sh
Handles MQTT-controlled volume adjustments.
- Subscribes to the master and per-channel `set` topics
- Validates input (0-100 range)
- Uses `amixer` to control system volume, reading per-channel levels (`Front Left` / `Front Right`)
- Publishes current master and per-channel state to the matching `state` topics

## Usage Examples

### Enable Volume Control Only
```bash
export ENABLE_VOLUME_CONTROL="true"
./mqtt.sh
```

### Set Volume via MQTT
```bash
# Both channels at once
mosquitto_pub -h 192.168.1.100 -u mqtt_user -P mqtt_password \
  -t "server/volume/set" -m "75"

# Left channel only
mosquitto_pub -h 192.168.1.100 -u mqtt_user -P mqtt_password \
  -t "server/volume/left/set" -m "60"

# Right channel only
mosquitto_pub -h 192.168.1.100 -u mqtt_user -P mqtt_password \
  -t "server/volume/right/set" -m "90"

# Mute / unmute / toggle a single side
mosquitto_pub -h 192.168.1.100 -u mqtt_user -P mqtt_password \
  -t "server/volume/left/mute/set" -m "TOGGLE"
```

### Monitor Volume State
```bash
# All state topics at once
mosquitto_sub -h 192.168.1.100 -u mqtt_user -P mqtt_password \
  -v -t "server/volume/state" -t "server/volume/+/state"
```

### Home Assistant Configuration

Add these MQTT `number` sliders to your `configuration.yaml` (under the `mqtt:` key):

```yaml
mqtt:
  number:
    - name: "Server Volume"
      command_topic: "server/volume/set"
      state_topic: "server/volume/state"
      min: 0
      max: 100
      step: 1
      unit_of_measurement: "%"

    - name: "Server Volume Left"
      command_topic: "server/volume/left/set"
      state_topic: "server/volume/left/state"
      min: 0
      max: 100
      step: 1
      unit_of_measurement: "%"

    - name: "Server Volume Right"
      command_topic: "server/volume/right/set"
      state_topic: "server/volume/right/state"
      min: 0
      max: 100
      step: 1
      unit_of_measurement: "%"

    - name: "Server Mute Left"
      command_topic: "server/volume/left/mute/set"
      state_topic: "server/volume/left/mute/state"
      payload_on: "MUTE"
      payload_off: "UNMUTE"
      state_on: "MUTED"
      state_off: "UNMUTED"

    - name: "Server Mute Right"
      command_topic: "server/volume/right/mute/set"
      state_topic: "server/volume/right/mute/state"
      payload_on: "MUTE"
      payload_off: "UNMUTE"
      state_on: "MUTED"
      state_off: "UNMUTED"

## Troubleshooting

### "Environment variable is not set"
Ensure all required variables are exported:
```bash
export BROKER_IP="your.broker.ip"
export PORT="1883"
export MQTT_USER="username"
export MQTT_PASS="password"
```

### Volume control not working
Verify `amixer` is installed:
```bash
which amixer
```

## Architecture

The system uses a modular architecture:
1. **mqtt.sh** - Orchestrator that spawns services as background processes
2. **volume_control.sh** - Long-running listener for volume changes

The service communicates via MQTT with the broker for remote control.

## Performance Considerations

- Uses MQTT retain flag for state persistence
- Low CPU overhead from the volume listener loop

## License

See LICENSE file for details.

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests.
