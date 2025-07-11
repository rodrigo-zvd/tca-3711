#!/bin/sh

# Construct the register command based on environment variables.
XO_REGISTER_COMMAND="xo-cli register"

if [ -n "$XO_ALLOW_UNAUTHORIZED" ] && [ "$XO_ALLOW_UNAUTHORIZED" = "true" ]; then
  XO_REGISTER_COMMAND="$XO_REGISTER_COMMAND --allowUnauthorized"
fi

if [ -n "$XO_URL" ] && [ -n "$XO_TOKEN" ]; then
  $XO_REGISTER_COMMAND --token "$XO_TOKEN" "$XO_URL"
elif [ -n "$XO_URL" ] && [ -n "$XO_USERNAME" ] && [ -n "$XO_PASSWORD" ]; then
  $XO_REGISTER_COMMAND "$XO_URL" "$XO_USERNAME" "$XO_PASSWORD"
else
  echo "Error: XO authentication variables are not set. Please define XO_URL and XO_TOKEN, or XO_URL, XO_USERNAME, and XO_PASSWORD."
  exit 1
fi

echo "---Registration Successful. Executing Command---"

# Check if a SCRIPT_FILE variable is set.
if [ -n "$SCRIPT_FILE" ] && [ -f "/scripts/$SCRIPT_FILE" ]; then
  echo "Executing script from ENV: $SCRIPT_FILE"
  # Use sh to execute the script, bypassing permission issues.
  sh "/scripts/$SCRIPT_FILE"
else
  # Otherwise, assume it's a direct command.
  echo "Executing command: $@"
  exec "$@"
fi