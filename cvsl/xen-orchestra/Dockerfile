# Base image
FROM ronivay/xen-orchestra:5.181.0

# Switch to root to install dependencies
USER root

# Install xen orchestrs command line (xo-cli)
RUN npm install --global xo-cli

# Install jq
RUN apt update && apt install jq -y



