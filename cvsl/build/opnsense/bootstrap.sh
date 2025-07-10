#!/bin/sh

# === CONFIGURATION PARAMETERS ===
TEMPLATE_XML="/conf/config-cloud-init.xml"
TARGET_XML="/conf/config.xml"
WAN_IF="xn1"
IP="192.168.1.49"
SUBNET="24"
GATEWAY="192.168.1.1"
DNS="8.8.8.8"

# === CHECK TEMPLATE EXISTS ===
if [ ! -f "$TEMPLATE_XML" ]; then
  echo "[!] Template file not found: $TEMPLATE_XML"
  exit 1
fi

# === BACKUP ACTIVE CONFIG BEFORE OVERWRITE ===
cp "$TARGET_XML" "${TARGET_XML}.bak"
echo "[*] Backup of current config created at ${TARGET_XML}.bak"

# === MODIFY TEMPLATE CONFIGURATION ===
# Update WAN IP, subnet and gateway reference
sed -i '' -E "/<interfaces>/,/<\/interfaces>/ {
  /<wan>/,/<\/wan>/ {
    s|<ipaddr>.*</ipaddr>|<ipaddr>${IP}</ipaddr>|
    s|<subnet>.*</subnet>|<subnet>${SUBNET}</subnet>|
    s|<gateway>.*</gateway>|<gateway>WAN_GW</gateway>|
  }
}" "$TEMPLATE_XML"

# Update WAN_GW gateway IP
sed -i '' -E "/<gateways>/,/<\/gateways>/ {
  /<gateway_item>/,/<\/gateway_item>/ {
    /<name>WAN_GW<\/name>/ {
      s|<gateway>.*</gateway>|<gateway>${GATEWAY}</gateway>|
    }
  }
}" "$TEMPLATE_XML"

# Update DNS server
sed -i '' -E "/<system>/,/<\/system>/ {
  s|<dnsserver>.*</dnsserver>|<dnsserver>${DNS}</dnsserver>|
}" "$TEMPLATE_XML"

# === APPLY TEMPLATE TO ACTIVE CONFIG ===
cp "$TEMPLATE_XML" "$TARGET_XML"
echo "[✔] Applied template config to ${TARGET_XML}"

# === REBOOT TO APPLY ===
echo "[↻] Rebooting OPNsense to apply new configuration..."
sleep 2
reboot