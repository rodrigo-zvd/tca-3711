#!/bin/sh

# This entrypoint handles authentication with Xen Orchestra and then passes
# control to the command specified in CMD or on the docker run line.

# Only attempt to register if XO_URL is provided.
# This allows the container to run without auth variables for other tasks.
if [ -n "$XO_URL" ]; then
    echo "Attempting to auto-register with Xen Orchestra..."

    # Construct the register command based on environment variables.
    XO_REGISTER_COMMAND="xo-cli register"

    if [ -n "$XO_ALLOW_UNAUTHORIZED" ] && [ "$XO_ALLOW_UNAUTHORIZED" = "true" ]; then
      XO_REGISTER_COMMAND="$XO_REGISTER_COMMAND --allowUnauthorized"
    fi

    if [ -n "$XO_TOKEN" ]; then
      $XO_REGISTER_COMMAND --token "$XO_TOKEN" "$XO_URL"
    elif [ -n "$XO_USERNAME" ] && [ -n "$XO_PASSWORD" ]; then
      $XO_REGISTER_COMMAND "$XO_URL" "$XO_USERNAME" "$XO_PASSWORD"
    fi
fi

# Execute the command provided to the container (from CMD or docker run).
exec "$@"