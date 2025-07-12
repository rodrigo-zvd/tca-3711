#!/bin/bash

# Define variables
# XO_URL=<your-url>
# XO_TOKEN=<your-token>

OPNSENSE_TAG=opnsense
# FILTER_TAG_URL will be set by a function

# Function to check if necessary environment variables are present
check_environment_variables() {
    if [ -z "$XO_URL" ] || [ -z "$XO_TOKEN" ]; then
        echo "❌ Error: XO_URL and XO_TOKEN environment variables must be defined."
        echo "To run the script, use:"
        echo "XO_URL=\"<your-url>\" XO_TOKEN=\"<your-token>\" bash opnsense.sh"
        exit 1 # Exit if variables are not set
    fi
}

# Function to format the tag URL for API requests
format_tag_url() {
    # This function sets the global variable FILTER_TAG_URL
    FILTER_TAG_URL=$(echo "tags:$OPNSENSE_TAG" | sed 's/:/%3A/')
    echo "🔗 Formatted tag URL: $FILTER_TAG_URL"
}

# Function to test direct API connection using curl
test_curl_api_connection() {
    echo "⚙️ --- Testing direct API connection with curl ---"
    echo "🔗 API URL: $XO_URL/rest/v0"

    # Use the 'curl' command to test the connection.
    # -k: Insecure, allows connections to servers with invalid certificates.
    # -b: Specifies the cookie data.
    response=$(curl -s -k -b "authenticationToken=$XO_TOKEN" "$XO_URL/rest/v0")
    local curl_exit_code=$? # Capture the exit code of curl

    if [ $curl_exit_code -eq 0 ]; then
        # Check if the response contains "rest/v0/hosts", which indicates a successful connection.
        if [[ "$response" == *"/rest/v0/hosts"* ]]; then
            echo "✅ Success: Direct API connection was successful."
        else
            echo "❌ Failure: Direct API connection was successful, but the API response was not as expected (e.g., Unauthorized)."
            echo "--- Raw Response ---"
            echo "$response"
            exit 1 # Exit on unexpected API response
        fi
    else
        echo "❌ Failure: Could not connect to the API via curl."
        echo "Please check the following:"
        echo "  - Is the server at $XO_URL online and reachable?"
        echo "  - Is the URL correct (e.g., no typos)?"
        echo "  - Is the XO_TOKEN still valid?"
        echo "Curl exit code: $curl_exit_code"
        exit 1 # Exit on curl connection failure
    fi
}

# Function to test xo-cli connection and authentication
test_xo_cli_connection() {
    echo "⚙️ --- Testing xo-cli connection and authentication ---"
    echo "🔗 Server URL: $XO_URL"

    # Capture the complete output (stdout and stderr) for reliable error checking.
    # The `xo-cli register` command is executed, and then, if authentication
    # is successful, the `xo-cli list-commands` is executed.
    # Since `xo-cli register` does not always fail at the shell level for logical errors,
    # we analyze the output of `list-commands` which is more reliable.
    output=$(xo-cli register --allowUnauthorized --token "$XO_TOKEN" "$XO_URL" 2>&1 && xo-cli list-commands 2>&1)

    # Check the output for specific error patterns.
    if [[ "$output" == *"EHOSTUNREACH"* ]] || [[ "$output" == *"connect ECONNREFUSED"* ]] || [[ "$output" == *"Failed to connect"* ]]; then
        echo "❌ Connection Failure: Could not reach the server using xo-cli."
        echo "Error details:"
        echo "$output"
        echo ""
        echo "Possible causes:"
        echo "  - The server at $XO_URL is not online or accessible."
        echo "  - There is a network issue, such as a firewall or incorrect route."
        echo "  - The IP address in XO_URL is incorrect."
        exit 1 # Exit on xo-cli connection failure
    elif [[ "$output" == *"invalid credentials"* ]]; then
        echo "❌ Authentication Failure: The provided token is invalid for xo-cli."
        echo "Error details:"
        echo "$output"
        echo ""
        echo "Possible causes:"
        echo "  - The value of the XO_TOKEN variable is incorrect."
        echo "  - The token might have expired or been revoked."
        exit 1 # Exit on xo-cli authentication failure
    # If no known errors are found, the connection and authentication were successful.
    elif [[ "$output" == *"acl.add"* ]]; then
        echo "✅ Success: xo-cli connection and authentication successful!"
    else
        # Handle other unexpected errors.
        echo "❌ Unexpected Failure: An unknown error occurred during xo-cli test."
        echo "Full command output:"
        echo "$output"
        exit 1 # Exit on any other unexpected xo-cli error
    fi
}

# --- Main Script Execution ---

# 1. Check environment variables first
check_environment_variables

# 2. Format the tag URL
format_tag_url

# 3. Run the connection tests
test_curl_api_connection
test_xo_cli_connection

echo "🎉 All connection tests passed successfully!"

# It will only execute if all above tests pass.

# Execute curl, filter with jq, and store UUIDs
UUIDS=$(curl -s -k -X 'GET' \
        -b "authenticationToken=$XO_TOKEN" \
        "${XO_URL}/rest/v0/vms?fields=name_label%2Cpower_state%2Cuuid&filter=$FILTER_TAG_URL" \
        -H 'accept: application/json' | jq -r '.[].uuid')

# Check if any UUID was found
if [ -z "$UUIDS" ]; then
  echo "🔍 No VM found with tag '$OPNSENSE_TAG'."
else
  # Loop to process each UUID, using a pipe instead of a here string
  echo "$UUIDS" | while IFS= read -r UUID; do
    echo "🖥️ VM UUID: $UUID"
    
    # Make a new request, filter VIFs and store in a variable
    VIFS=$(curl -s -k -X 'GET' \
           -b "authenticationToken=$XO_TOKEN" \
           "${XO_URL}/rest/v0/vms/$UUID" \
           -H 'accept: application/json' | jq -r '.VIFs[]')
    
    # Check if the VM has VIFs and display them
    if [ -z "$VIFS" ]; then
      echo "⚠️ VM $UUID has no VIFs."
    else
        echo "📋 VIFs found for VM $UUID:"
        echo "$VIFS" | while IFS= read -r VIF_ID; do
            echo "      🌐 VIF: $VIF_ID"
            
            # Capture the txChecksumming status in a variable
            TX_CHECKSUMMING_STATUS=$(curl -s -k -X 'GET' \
                -b "authenticationToken=$XO_TOKEN" \
                "${XO_URL}/rest/v0/vifs/$VIF_ID" \
                -H 'accept: application/json' | jq -r '.txChecksumming'
            )
            
            # Check if the status is 'true' before executing the xo-cli command
            if [ "$TX_CHECKSUMMING_STATUS" = "true" ]; then
                echo "          🔧 txChecksumming is enabled. Disabling..."
                xo-cli vif.set id=$VIF_ID txChecksumming=false
            else
                echo "          ✔️ txChecksumming is already disabled."
            fi
        done
    fi
  done
fi