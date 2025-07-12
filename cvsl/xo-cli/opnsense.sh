#!/bin/bash

# Define variables
#XO_URL=<your-url>
#XO_TOKEN=<your-token>
OPNSENSE_TAG=opnsense
FILTER_TAG_URL=$(echo "tags:$OPNSENSE_TAG" | sed 's/:/%3A/')

# Check if necessary environment variables are present
if [ -z "$XO_URL" ] || [ -z "$XO_TOKEN" ]; then
  echo "Error: XO_URL and XO_TOKEN environment variables must be defined."
  echo "To run the script, use:"
  echo "XO_URL=\"<your-url>\" XO_TOKEN=\"<your-token>\" bash opnsense.sh"
  exit 1
fi

# Execute curl, filter with jq, and store UUIDs
UUIDS=$(curl -k -X 'GET' \
        -b "authenticationToken=$XO_TOKEN" \
        "${XO_URL}/rest/v0/vms?fields=name_label%2Cpower_state%2Cuuid&filter=$FILTER_TAG_URL" \
        -H 'accept: application/json' | jq -r '.[].uuid')

# Check if any UUID was found
if [ -z "$UUIDS" ]; then
  echo "No VM found with tag '$OPNSENSE_TAG'."
else
  # Loop to process each UUID, using a pipe instead of a here string
  echo "$UUIDS" | while IFS= read -r UUID; do
    echo "VM UUID: $UUID"
    
    # Make a new request, filter VIFs and store in a variable
    VIFS=$(curl -s -k -X 'GET' \
           -b "authenticationToken=$XO_TOKEN" \
           "${XO_URL}/rest/v0/vms/$UUID" \
           -H 'accept: application/json' | jq -r '.VIFs[]')
    
    # Check if the VM has VIFs and display them
    if [ -z "$VIFS" ]; then
      echo "  VM $UUID has no VIFs."
    else
        echo "  VIFs found for VM $UUID:"
        echo "$VIFS" | while IFS= read -r VIF_ID; do
            echo "- $VIF_ID"
            
            # Capture the txChecksumming status in a variable
            TX_CHECKSUMMING_STATUS=$(curl -s -k -X 'GET' \
                -b "authenticationToken=$XO_TOKEN" \
                "${XO_URL}/rest/v0/vifs/$VIF_ID" \
                -H 'accept: application/json' | jq -r '.txChecksumming'
            )
            
            # Check if the status is 'true' before executing the xo-cli command
            if [ "$TX_CHECKSUMMING_STATUS" = "true" ]; then
                echo "    txChecksumming is enabled. Disabling..."
                xo-cli vif.set id=$VIF_ID txChecksumming=false
            else
                echo "    txChecksumming is already disabled."
            fi
        done
    fi
  done
fi