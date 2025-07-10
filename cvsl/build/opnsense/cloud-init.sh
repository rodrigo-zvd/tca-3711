#!/bin/sh

# === CONFIGURAÇÃO DE LOG ===
LOG_FILE="/var/log/opnsense-initial-config.log"

# Função para logar mensagens, tanto no console quanto no arquivo
log_message() {
  echo "$(date): $1" | tee -a "$LOG_FILE"
}

log_message "Iniciando script de configuração inicial para OPNsense."

# === VARIÁVEIS DE CONTROLE ===
BOOT_FLAG_FILE="/conf/opnsense_initial_config_done"
USER_DATA_DEVICE="/dev/ada1s1" # Partição FAT32 (slice 1)
USER_DATA_MOUNT_POINT="/mnt/opnsense-user-data"
USER_DATA_FILE="user-data" # Nome do arquivo user-data no disco

# === VERIFICAÇÃO DE PRIMEIRO BOOT ===
if [ -f "$BOOT_FLAG_FILE" ]; then
  log_message "Script já executado em um boot anterior. Saindo."
  exit 0
fi

# === MONTAGEM DO DISCO E PARSE DO ARQUIVO YAML ===
# Removida a checagem '-b' conforme solicitado, prosseguindo diretamente para a montagem.
log_message "Tentando montar $USER_DATA_DEVICE para ler user-data."
mkdir -p "$USER_DATA_MOUNT_POINT"

# Tentativa de montagem de diferentes tipos de sistemas de arquivos
# Priorizamos 'msdosfs' (FAT32) que foi confirmado manualmente, depois 'cd9660' e 'ufs'.
MOUNT_SUCCESS=0
for fs_type in msdosfs cd9660 ufs; do
  log_message "Tentando montar $USER_DATA_DEVICE como $fs_type..."
  if mount -t "$fs_type" "$USER_DATA_DEVICE" "$USER_DATA_MOUNT_POINT"; then
    log_message "Partição $USER_DATA_DEVICE montada com sucesso como $fs_type."
    MOUNT_SUCCESS=1
    break
  fi
done

if [ "$MOUNT_SUCCESS" -eq 0 ]; then
  log_message "Falha ao montar $USER_DATA_DEVICE. Nenhuma das tentativas de sistema de arquivos (msdosfs, cd9660, ufs) funcionou. Verifique o formato da partição."
  rmdir "$USER_DATA_MOUNT_POINT"
  exit 1
fi

USER_DATA_PATH="$USER_DATA_MOUNT_POINT/$USER_DATA_FILE"

if [ ! -f "$USER_DATA_PATH" ]; then
  log_message "Arquivo user-data '$USER_DATA_FILE' não encontrado em $USER_DATA_PATH. Desmontando e saindo."
  umount "$USER_DATA_MOUNT_POINT"
  rmdir "$USER_DATA_MOUNT_POINT"
  exit 1
fi

log_message "Lendo parâmetros do arquivo YAML: $USER_DATA_PATH"

# --- PARSE DO YAML COM COMANDOS NATIVOS ---
# Função auxiliar para extrair valores de YAML simples, agora com trim mais robusto de espaços.
get_yaml_value() {
  local key="$1"
  local file="$2"
  # Procura pela linha que contém a chave, remove espaços em branco no início/fim da linha,
  # extrai o valor após ': ' e remove aspas (se presentes) e '\r' (CR).
  grep "^  $key:" "$file" | sed -E "s/^  $key:[[:space:]]*(.*)[[:space:]]*$/\1/" | sed -E "s/^\"(.*)\"$/\1/" | tr -d '\r'
}

TEMPLATE_XML=$(get_yaml_value "TEMPLATE_XML" "$USER_DATA_PATH")
TARGET_XML=$(get_yaml_value "TARGET_XML" "$USER_DATA_PATH")
WAN_IF=$(get_yaml_value "WAN_IF" "$USER_DATA_PATH")
IP=$(get_yaml_value "IP" "$USER_DATA_PATH")
SUBNET=$(get_yaml_value "SUBNET" "$USER_DATA_PATH")
GATEWAY=$(get_yaml_value "GATEWAY" "$USER_DATA_PATH")
DNS=$(get_yaml_value "DNS" "$USER_DATA_PATH")

# Desmontar o disco
log_message "Desmontando $USER_DATA_MOUNT_POINT."
umount "$USER_DATA_MOUNT_POINT"
rmdir "$USER_DATA_MOUNT_POINT"

# === VERIFICAÇÃO DE VARIÁVEIS ===
if [ -z "$TEMPLATE_XML" ] || [ -z "$TARGET_XML" ] || [ -z "$IP" ] || [ -z "$SUBNET" ] || [ -z "$GATEWAY" ] || [ -z "$DNS" ]; then
  log_message "Erro: Uma ou mais variáveis essenciais não foram carregadas do user-data. Verifique o arquivo YAML e a sua formatação."
  exit 1
fi

log_message "Variáveis carregadas: IP=$IP, GATEWAY=$GATEWAY, DNS=$DNS, TEMPLATE_XML=$TEMPLATE_XML" # Adicionado TEMPLATE_XML ao log para depuração

# === CHECK TEMPLATE EXISTS ===
if [ ! -f "$TEMPLATE_XML" ]; then
  log_message "[!] Template file not found: '$TEMPLATE_XML'. Verifique se o caminho no user-data está exato." # Mensagem de erro aprimorada
  exit 1
fi

# === BACKUP ACTIVE CONFIG BEFORE OVERWRITE ===
cp "$TARGET_XML" "${TARGET_XML}.bak"
log_message "[*] Backup of current config created at ${TARGET_XML}.bak"

# === MODIFY TEMPLATE CONFIGURATION ===
log_message "Modificando configuração do template..."
sed -i '' -E "/<interfaces>/,/<\/interfaces>/ {
  /<wan>/,/<\/wan>/ {
    s|<ipaddr>.*</ipaddr>|<ipaddr>${IP}</ipaddr>|
    s|<subnet>.*</subnet>|<subnet>${SUBNET}</subnet>|
    s|<gateway>.*</gateway>|<gateway>WAN_GW</gateway>|
  }
}" "$TEMPLATE_XML"

sed -i '' -E "/<gateways>/,/<\/gateways>/ {
  /<gateway_item>/,/<\/gateway_item>/ {
    /<name>WAN_GW<\/name>/ {
      s|<gateway>.*</gateway>|<gateway>${GATEWAY}</gateway>|
    }
  }
}" "$TEMPLATE_XML"

sed -i '' -E "/<system>/,/<\/system>/ {
  s|<dnsserver>.*</dnsserver>|<dnsserver>${DNS}</dnsserver>|
}" "$TEMPLATE_XML"

log_message "Configuração do template modificada com sucesso."

# === APPLY TEMPLATE TO ACTIVE CONFIG ===
cp "$TEMPLATE_XML" "$TARGET_XML"
log_message "[✔] Applied template config to ${TARGET_XML}"

# === MARCAR EXECUÇÃO PARA EVITAR REPETIÇÃO ===
touch "$BOOT_FLAG_FILE"
log_message "Marcado para não executar em boots futuros."

# === REBOOT TO APPLY ===
log_message "[↻] Rebooting OPNsense to apply new configuration..."
sleep 5
reboot