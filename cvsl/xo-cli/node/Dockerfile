# Use a Node.js base image with a specific tag for stability.
FROM node:20.19.3-slim

# Set the working directory inside the container.
WORKDIR /scripts

# Install necessary system packages: jq for JSON parsing and python3 for Python scripts.
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the entrypoint script into the container.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Ensure the entrypoint script is executable.
RUN chmod +x /usr/local/bin/entrypoint.sh

# Install the xo-cli globally.
RUN npm install --global xo-cli

# Set the entrypoint for the container.
ENTRYPOINT ["entrypoint.sh"]

# Set a default command to be run if no command is provided.
CMD ["xo-cli", "--help"]