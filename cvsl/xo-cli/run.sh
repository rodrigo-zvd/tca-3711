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

docker run --rm -it \
-e XO_URL="https://192.168.1.40" \
-e XO_TOKEN="uF3Tzz01I4tEdPjb8vULOdKzXsq4hs3vS_mljZXx7Yc" \
-e XO_ALLOW_UNAUTHORIZED=true \
-v $(pwd):/scripts \
rodrigorao/xo-cli:alpine "/scripts/opnsense.sh"

# No seu host Jenkins
cd /var/jenkins_home/workspace/Build\ Lab\ CVSL/cvsl/xo-cli

# Execute o comando com as variáveis de ambiente
# (certifique-se de substituir os valores `xxxx` pelos corretos)
docker run --rm -e XO_URL="https://192.168.1.40" -e XO_TOKEN="uF3Tzz01I4tEdPjb8vULOdKzXsq4hs3vS_mljZXx7Yc" -e XO_ALLOW_UNAUTHORIZED=true -v ${PWD}:/scripts rodrigorao/xo-cli:alpine sh -x /scripts/opnsense.sh