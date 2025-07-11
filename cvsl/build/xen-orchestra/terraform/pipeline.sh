docker run --rm -it \
  -e XO_URL="https://${XOA_IP}" \
  -e XO_USERNAME="admin@admin.net" \
  -e XO_PASSWORD="admin" \
  -e XCP_MASTER_IP=${XCP_MASTER_IP} \
  -e XCP_USER=${XCP_USER} \
  -e XCP_PASSWORD=${XCP_PASSWORD} \
  -e XOA_USER=${XOA_USER} \
  -e XOA_PASSWORD=${XOA_PASSWORD} \
  -e XO_ALLOW_UNAUTHORIZED=true \
  -e SCRIPT_FILE="xo_setup.sh" \
  -v $(pwd):/scripts \
  rodrigorao/xo-cli:0.32.2