#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define the desired number of templates
TEMPLATE_COUNT=1 # You can change this value as needed

# --- NETWORK CONFIGURATIONS (Same for all instances) ---
export TEMPLATE_VLAN="LAN"     # IP address for the admin interface
export TEMPLATE_IP="192.168.1.49"     # IP address for the admin interface
export TEMPLATE_SUBNET="255.255.255.0"     # Subnet mask
export TEMPLATE_GATEWAY="192.168.1.5"      # Default gateway
export TEMPLATE_NAME_SERVER="8.8.8.8"  # Primary DNS server (can be comma-separated for multiple)

# --- OTHER INSTALLATION CONFIGURATIONS ---
export TEMPLATE_ROOT_PASSWORD="123456" # Password for the root user on XCP-ng (change to a strong password!)
export TEMPLATE_KEYMAP="br-abnt2"          # Keyboard layout (e.g., us, gb, de, fr, br-abnt2)
export TEMPLATE_PRIMARY_DISK="sda"         # Primary disk where XCP-ng will be installed (e.g., sda, vda)
export TEMPLATE_TIMEZONE="America/Sao_Paulo" # Timezone (e.g., America/New_York, Europe/London, Asia/Tokyo)

# --- OUTPUT DIRECTORY ---
export HTTP_SERVER_URL="http://192.168.1.110"
export ANSWERFILE_URL="http://192.168.1.110"
export ANSWERFILE_PATH="answerfile/answerfile.xml" # Path to the answerfile relative to ANSWERFILE_URL
export ANSWERFILE_OUTPUT_DIR="answerfile" # Directory where the answer file will be saved

export XCP_NG_ISO_VERSION="8.2.1" # Adjust if your XCP-ng version is different
export XCP_NG_ISO_URL_FILE="https://mirror.uepg.br/xcp-ng/isos/8.2/xcp-ng-8.2.1-20231130.iso"
export XCP_NG_ISO_SHA256="108aa7144d1f5dd169a1b99ca70b510527136c549f2e3c3c1707b619e17ee1b6" # <<< IMPORTANT: Set this to your actual SHA256 checksum!

export XCP_NG_HOST="192.168.1.10"
export XCP_NG_USER="root"
export XCP_NG_PASSWORD="m3gaFox50"
export POOL_NAME="xcp-optiplex"
export POOL_SR="Local storage"
export XOA_URL="https://192.168.1.20:8443"
export XOA_TOKEN="Rf7dqNSsZOEGGsP14q7m8RgXH-jmx80I5C9ahsMq280"


export XCP_NG_SR_ISO_NAME="XCPngUnattendedInstall_ISOs"
export XCP_NG_SR_ISO_PATH="/XCP-ng-Unattended-Install-ISOs"

export XCP_NG_UNATTENDED_INSTALL_ISO_NAME="xcp-ng-${XCP_NG_ISO_VERSION}-unattended-install.iso"
export XCP_NG_UNATTENDED_INSTALL_URL="${HTTP_URL}/isos/${XCP_NG_UNATTENDED_INSTALL_ISO_NAME}"

# Cria a variável XOA_URL_TF a partir de XOA_URL
XOA_URL_TF="${XOA_URL}"

# Verifica e substitui 'https' por 'wss'
if [[ "${XOA_URL_TF}" == https* ]]; then
    XOA_URL_TF="${XOA_URL_TF/https/wss}"
# Verifica e substitui 'http' por 'ws'
elif [[ "${XOA_URL_TF}" == http* ]]; then
    XOA_URL_TF="${XOA_URL_TF/http/ws}"
fi

# --- Docker Container Cleanup (added to prevent "Conflict" error) ---
echo "Checking for existing xcp-build-http-server container..."
if docker ps -a --format '{{.Names}}' | grep -q "xcp-build-http-server"; then
    echo "Found existing xcp-build-http-server container. Stopping and removing..."
    docker stop xcp-build-http-server || { echo "Error: Failed to stop existing HTTP server container. Exiting."; exit 1; }
    docker rm xcp-build-http-server || { echo "Error: Failed to remove existing HTTP server container. Exiting."; exit 1; }
    echo "Existing HTTP server container stopped and removed."
else
    echo "No existing xcp-build-http-server container found."
fi
# --- End Docker Container Cleanup ---

echo "Starting HTTP server..."
docker run -d \
  -p 80:80 \
  -v "$(pwd)/isos:/usr/local/apache2/htdocs/isos" \
  -v "$(pwd)/answerfile:/usr/local/apache2/htdocs/answerfile" \
  --name xcp-build-http-server \
  httpd:latest || { echo "Error: Failed to start HTTP server. Exiting."; exit 1; }
echo "HTTP server started."

echo "Generating answerfile..."
./generate_answerfile.sh || { echo "Error: generate_answerfile.sh failed. Exiting."; exit 1; }
echo "Answerfile generated."

echo "Creating unattended-install ISO..."
./create_unattended_iso.sh || { echo "Error: create_autoinstall_iso.sh failed. Exiting."; exit 1; }
echo "Unattended-install ISO created."

echo "Creating SR ISO..."
./sr_iso.sh create || { echo "Error: sr_iso.sh failed. Exiting."; exit 1; }
echo "SR ISO created."

# Loop to create multiple templates
for i in $(seq 1 $TEMPLATE_COUNT); do
    echo "--- Creating template $i of $TEMPLATE_COUNT ---"
    CURRENT_TEMPLATE_INDEX=$i

    echo "Navigating to terraform directory..."
    cd terraform/ || { echo "Error: Failed to change directory to terraform/. Exiting."; exit 1; }

    echo "Initializing Terraform..."
    terraform init || { echo "Error: Terraform initialization failed. Exiting."; exit 1; }
    echo "Terraform initialized."

    echo "Planning Terraform deployment for template $CURRENT_TEMPLATE_INDEX with IP $TEMPLATE_IP..."
    terraform plan \
      -var="xoa_url=$XOA_URL_TF" \
      -var="xoa_token=$XOA_TOKEN" \
      -var="pool_name=$POOL_NAME" \
      -var="pool_sr=$POOL_SR" \
      -var="vm_template_vlan=$TEMPLATE_VLAN" \
      -var="vm_template_ip=$TEMPLATE_IP" \
      -var="vm_template_netmask=$TEMPLATE_SUBNET" \
      -var="vm_template_gateway=$TEMPLATE_GATEWAY" \
      -var="vm_template_user=root" \
      -var="vm_template_password=$TEMPLATE_ROOT_PASSWORD" \
      -var="vm_template_iso=$XCP_NG_UNATTENDED_INSTALL_ISO_NAME" || { echo "Error: Terraform plan failed. Exiting."; exit 1; }
    echo "Terraform plan complete."

    echo "Applying Terraform deployment for template $CURRENT_TEMPLATE_INDEX..."
    terraform apply \
      -var="xoa_url=$XOA_URL_TF" \
      -var="xoa_token=$XOA_TOKEN" \
      -var="pool_name=$POOL_NAME" \
      -var="pool_sr=$POOL_SR" \
      -var="vm_template_vlan=$TEMPLATE_VLAN" \
      -var="vm_template_ip=$TEMPLATE_IP" \
      -var="vm_template_netmask=$TEMPLATE_SUBNET" \
      -var="vm_template_gateway=$TEMPLATE_GATEWAY" \
      -var="vm_template_user=root" \
      -var="vm_template_password=$TEMPLATE_ROOT_PASSWORD" \
      -var="vm_template_iso=$XCP_NG_UNATTENDED_INSTALL_ISO_NAME" \
      -auto-approve || { echo "Error: Terraform apply failed. Exiting."; exit 1; }
    echo "Terraform apply complete."

    export VM_ID=$(terraform output -raw vm-id) || { echo "Error: Failed to get VM ID from Terraform output. Exiting."; exit 1; }
    echo "VM_ID for current template: $VM_ID"

    echo "Registering XO CLI and performing VM operations..."
    xo-cli register --allowUnauthorized --token "$XOA_TOKEN" "$XOA_URL" || { echo "Error: XO CLI registration failed. Exiting."; exit 1; }
    xo-cli vm.ejectCd id="$VM_ID" || { echo "Error: Failed to eject CD from VM $VM_ID. Exiting."; exit 1; }
    xo-cli vm.stop id="$VM_ID" force=true || { echo "Error: Failed to stop VM $VM_ID. Exiting."; exit 1; }
    xo-cli vm.set name_label="template-xcp-ng-${XCP_NG_ISO_VERSION}-id-${CURRENT_TEMPLATE_INDEX}" nestedVirt=true expNestedHvm=true nicType="e1000" id="$VM_ID" || { echo "Error: Failed to set VM properties for $VM_ID. Exiting."; exit 1; }
    xo-cli vm.convertToTemplate id="$VM_ID" || { echo "Error: Failed to convert VM $VM_ID to template. Exiting."; exit 1; }
    echo "VM $VM_ID converted to template."

    echo "Navigating back to parent directory..."
    cd .. || { echo "Error: Failed to change directory back. Exiting."; exit 1; }

    echo "--- Template $CURRENT_TEMPLATE_INDEX creation complete ---"
done

echo "Stopping and removing HTTP server..."
docker stop xcp-build-http-server && docker rm xcp-build-http-server || { echo "Error: Failed to stop/remove HTTP server. Exiting."; exit 1; }
echo "HTTP server stopped and removed."

echo "Destroying SR ISO..."
./sr_iso.sh destroy || { echo "Error: sr_iso.sh destroy failed. Exiting."; exit 1; }
echo "SR ISO destroyed."

echo "Script execution finished."