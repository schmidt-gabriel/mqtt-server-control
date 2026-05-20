FROM debian:bookworm-slim

# Install ALSA tools, Mosquitto client, and bash for volume control
RUN apt-get update && apt-get install -y \
    alsa-utils \
    mosquitto-clients \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Copy mqtt.sh to the root and scripts to /usr/local/bin/scripts
COPY mqtt.sh /usr/local/bin/mqtt.sh
COPY scripts/ /usr/local/bin/scripts/
RUN chmod +x /usr/local/bin/mqtt.sh /usr/local/bin/scripts/*.sh

# Run the script directly as the main process
CMD ["/usr/local/bin/mqtt.sh"]
