docker run --rm -it \
  -e XO_URL="https://${XOA_IP}" \
  -e XO_TOKEN="uF3Tzz01I4tEdPjb8vULOdKzXsq4hs3vS_mljZXx7Yc" \
  -e XO_ALLOW_UNAUTHORIZED=true \
  -e SCRIPT_FILE="opnsense.sh" \
  -v $(pwd):/scripts \
  rodrigorao/xo-cli:alpine

docker run --rm -it \
-e XO_URL="https://${XOA_IP}" \
-e XO_TOKEN="uF3Tzz01I4tEdPjb8vULOdKzXsq4hs3vS_mljZXx7Yc" \
-e XO_ALLOW_UNAUTHORIZED=true \
-e SCRIPT_FILE="opnsense.sh" \
-v $(pwd):/scripts \
rodrigorao/xo-cli:alpine "/scripts/opnsense.sh"