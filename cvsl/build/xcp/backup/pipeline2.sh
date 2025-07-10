#!/bin/bash

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
export ANSWERFILE_URL="http://192.168.1.110"
export ANSWERFILE_PATH="answerfile/answerfile.xml" # Path to the answerfile relative to ANSWERFILE_URL
export ANSWERFILE_OUTPUT_DIR="answerfile" # Directory where the answer file will be saved

export XCP_NG_ISO_VERSION="8.3.0" # Adjust if your XCP-ng version is different
export XCP_NG_ISO_URL_FILE="https://mirror.uepg.br/xcp-ng/isos/8.3/xcp-ng-8.3.0-20250606.iso"
export XCP_NG_ISO_SHA256="4d6f5a99da0d70920bc313470ad2b14decab66038f0863ca68a2b81126ee2977" # <<< IMPORTANT: Set this to your actual SHA256 checksum!
export XCP_NG_AUTOINSTALL_ISO_NAME="xcp-ng-${XCP_NG_ISO_VERSION}-autoinstall.iso"

export XCP_NG_HOST="192.168.1.10"
export XCP_NG_USER="root"
export XCP_NG_PASSWORD="m3gaFox50"

export XCP_NG_AUTOINSTALL_URL="http://192.168.1.110/isos/${XCP_NG_AUTOINSTALL_ISO_NAME}"
export XCP_NG_SR_ISO_NAME="XCPngAutoInstall_ISOs"
export XCP_NG_SR_ISO_PATH="/var/run/sr-mount/xcp-iso-sr"

export XOA_URL="https://192.168.1.20:8443"
export XOA_TOKEN="Rf7dqNSsZOEGGsP14q7m8RgXH-jmx80I5C9ahsMq280"

export POOL_NAME="xcp-optiplex"
export POOL_SR="Local storage"




# Cria a variável XOA_URL_TF a partir de XOA_URL
XOA_URL_TF="${XOA_URL}"

# Verifica e substitui 'https' por 'wss'
if [[ "${XOA_URL_TF}" == https* ]]; then
    XOA_URL_TF="${XOA_URL_TF/https/wss}"
# Verifica e substitui 'http' por 'ws'
elif [[ "${XOA_URL_TF}" == http* ]]; then
    XOA_URL_TF="${XOA_URL_TF/http/ws}"
fi


# docker run -d \
#   -p 80:80 \
#   -v "$(pwd)/isos:/usr/local/apache2/htdocs/isos" \
#   -v "$(pwd)/answerfile:/usr/local/apache2/htdocs/answerfile" \
#   --name xcp-build-http-server \
#   httpd:latest

./generate_answerfile.sh

./create_autoinstall_iso.sh

./create_sr_iso.sh create

# cd terraform/

# terraform init

# terraform plan \
#   -var="xoa_url=$XOA_URL_TF" \
#   -var="xoa_token=$XOA_TOKEN" \
#   -var="pool_name=$POOL_NAME" \
#   -var="pool_sr=$POOL_SR" \
#   -var="vm_template_vlan=$TEMPLATE_VLAN" \
#   -var="vm_template_ip=$TEMPLATE_IP" \
#   -var="vm_template_netmask=$TEMPLATE_NETMASK" \
#   -var="vm_template_gateway=$TEMPLATE_GATEWAY" \
#   -var="vm_template_user=root" \
#   -var="vm_template_password=$TEMPLATE_ROOT_PASSWORD" \
#   -var="vm_template_iso=xcp-ng-8.3.0-autoinstall.iso"

# # For apply, add -auto-approve if you want to bypass the confirmation
# terraform apply \
#   -var="xoa_url=$XOA_URL_TF" \
#   -var="xoa_token=$XOA_TOKEN" \
#   -var="pool_name=$POOL_NAME" \
#   -var="pool_sr=$POOL_SR" \
#   -var="vm_template_vlan=$TEMPLATE_VLAN" \
#   -var="vm_template_ip=$TEMPLATE_IP" \
#   -var="vm_template_netmask=$TEMPLATE_NETMASK" \
#   -var="vm_template_gateway=$TEMPLATE_GATEWAY" \
#   -var="vm_template_user=root" \
#   -var="vm_template_password=$TEMPLATE_ROOT_PASSWORD" \
#   -var="vm_template_iso=xcp-ng-8.3.0-autoinstall.iso" \
#   -auto-approve

# export VM_ID=$(terraform output -raw vm-id)


# xo-cli register --allowUnauthorized --token $XOA_TOKEN $XOA_URL
# xo-cli vm.ejectCd id=$VM_ID
# xo-cli vm.stop id=$VM_ID force=true
# xo-cli vm.set name_label="template-xcp-ng-$XCP_NG_ISO_VERSION-$TEMPLATE_COUNT" nestedVirt=true expNestedHvm=true nicType="e1000" id=$VM_ID
# xo-cli vm.convertToTemplate id=$VM_ID

# docker stop xcp-build-http-server && docker rm xcp-build-http-server

# # ./create_sr_iso.sh destroy

