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
export USER="mqtt_user"
export PASS="mqtt_password"
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
  -e USER="mqtt_user" \
  -e PASS="mqtt_password" \
  -e ENABLE_VOLUME_CONTROL="true" \
  mqtt-server-control
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BROKER_IP` | Yes | - | MQTT broker IP address |
| `PORT` | Yes | - | MQTT broker port |
| `USER` | Yes | - | MQTT username |
| `PASS` | Yes | - | MQTT password |
| `ENABLE_VOLUME_CONTROL` | No | false | Enable volume control service |

## MQTT Topics

### Volume Control Topics
```
server/volume/set     → Subscribe to set volume (0-100)
server/volume/state   → Publish current volume level
```

The current volume state is published with the **retain flag** (`-r`) to maintain state after reconnection.

## Files

### mqtt.sh
Main entry point script that orchestrates the services.
- Validates environment variables
- Starts volume control service (if enabled)
- Manages background processes

### volume_control.sh
Handles MQTT-controlled volume adjustments.
- Subscribes to `server/volume/set` topic
- Validates input (0-100 range)
- Uses `amixer` to control system volume
- Publishes current volume state to `server/volume/state`

## Usage Examples

### Enable Volume Control Only
```bash
export ENABLE_VOLUME_CONTROL="true"
./mqtt.sh
```

### Set Volume via MQTT
```bash
mosquitto_pub -h 192.168.1.100 -u mqtt_user -P mqtt_password \
  -t "server/volume/set" -m "75"
```

### Monitor Volume State
```bash
mosquitto_sub -h 192.168.1.100 -u mqtt_user -P mqtt_password \
  -t "server/volume/state"
```

## Troubleshooting

### "Environment variable is not set"
Ensure all required variables are exported:
```bash
export BROKER_IP="your.broker.ip"
export PORT="1883"
export USER="username"
export PASS="password"
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
