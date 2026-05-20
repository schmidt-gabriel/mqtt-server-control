# MQTT Server Control

A comprehensive Bash-based system for monitoring and controlling server resources via MQTT. This project provides real-time monitoring of CPU, memory, temperature, disk usage, and volume control, all integrated with an MQTT broker for seamless remote management.

## Features

-  **Volume Control**: Remote volume management via MQTT topics
-  **System Monitoring**: Real-time CPU, memory, temperature, power, and disk usage metrics
-  **MQTT Integration**: Publish metrics to MQTT broker with retain flag for persistence
-  **Docker Support**: Easily deployable as a Docker container
-  **Configurable**: Enable/disable features via environment variables
-  **Error Handling**: Comprehensive validation and graceful degradation

## Requirements

- Bash 4.0+
- `mosquitto_pub` and `mosquitto_sub` (MQTT client tools)
- `amixer` (for volume control)
- `top` (for CPU/memory monitoring)
- `free` (for memory info)
- `df` (for disk usage)
- Optional: `sensors` (for CPU temperature)
- Optional: `turbostat` (for CPU power consumption)

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
export ENABLE_SYSTEM_MONITOR="true"
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
  -P PASS="mqtt_password" \
  -e ENABLE_VOLUME_CONTROL="true" \
  -e ENABLE_SYSTEM_MONITOR="true" \
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
| `ENABLE_SYSTEM_MONITOR` | No | false | Enable system monitoring service |

## MQTT Topics

### Volume Control Topics
```
server/volume/set     → Subscribe to set volume (0-100)
server/volume/state   → Publish current volume level
```

### System Monitoring Topics
```
server/system/cpu         → CPU usage percentage (0-100)
server/system/memory      → Memory usage percentage (0-100)
server/system/cpu_temp    → CPU temperature in Celsius
server/system/cpu_power   → CPU power consumption in Watts
server/system/disk        → Disk usage percentage (0-100)
```

All metrics are published with the **retain flag** (-r) to maintain state after reconnection.

## Files

### mqtt.sh
Main entry point script that orchestrates the services.
- Validates environment variables
- Starts volume control service (if enabled)
- Starts system monitoring service (if enabled)
- Manages background processes

### volume_control.sh
Handles MQTT-controlled volume adjustments.
- Subscribes to `server/volume/set` topic
- Validates input (0-100 range)
- Uses `amixer` to control system volume
- Publishes current volume state to `server/volume/state`

### system_monitor.sh
Continuous system resource monitoring.
- Collects metrics every 5 seconds
- Publishes to respective MQTT topics
- Gracefully handles missing tools (returns "N/A")
- Real-time console logging

## Usage Examples

### Enable Volume Control Only
```bash
export ENABLE_VOLUME_CONTROL="true"
export ENABLE_SYSTEM_MONITOR="false"
./mqtt.sh
```

### Enable System Monitoring Only
```bash
export ENABLE_VOLUME_CONTROL="false"
export ENABLE_SYSTEM_MONITOR="true"
./mqtt.sh
```

### Enable All Services
```bash
export ENABLE_VOLUME_CONTROL="true"
export ENABLE_SYSTEM_MONITOR="true"
./mqtt.sh
```

### Set Volume via MQTT
```bash
mosquitto_pub -h 192.168.1.100 -u mqtt_user -P mqtt_password \
  -t "server/volume/set" -m "75"
```

### Monitor Metrics
```bash
mosquitto_sub -h 192.168.1.100 -u mqtt_user -P mqtt_password \
  -t "server/system/#"
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

### CPU temperature shows "N/A"
Install lm-sensors:
```bash
sudo apt-get install lm-sensors
```

### CPU power shows "N/A"
Install turbostat:
```bash
sudo apt-get install linux-tools-generic
```

## Architecture

The system uses a modular architecture:
1. **mqtt.sh** - Orchestrator that spawns services as background processes
2. **volume_control.sh** - Long-running listener for volume changes
3. **system_monitor.sh** - Continuous monitoring loop with 5-second intervals

All services communicate via MQTT with the broker, allowing for distributed monitoring and control.

## Performance Considerations

- System monitoring publishes every 5 seconds (adjustable in system_monitor.sh)
- Uses MQTT retain flag for state persistence
- Low CPU overhead from monitoring scripts
- Graceful handling of unavailable monitoring tools

## License

See LICENSE file for details.

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests.
