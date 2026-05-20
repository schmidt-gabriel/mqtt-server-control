FROM debian:bookworm-slim

# Install ALSA tools, Mosquitto client, and bash
RUN apt-get update && apt-get install -y \
    alsa-utils \
    mosquitto-clients \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Copy all scripts into the container
COPY scripts/*.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Run the script directly as the main process
CMD ["/usr/local/bin/mqtt.sh"]
