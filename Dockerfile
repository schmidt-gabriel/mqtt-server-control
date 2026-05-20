FROM debian:bookworm-slim

# Install ALSA tools, Mosquitto client, and bash
RUN apt-get update && apt-get install -y \
    alsa-utils \
    mosquitto-clients \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Copy your script into the container
COPY mqtt_volume.sh /usr/local/bin/mqtt.sh
RUN chmod +x /usr/local/bin/mqtt.sh

# Run the script directly as the main process
CMD ["/usr/local/bin/mqtt.sh"]
