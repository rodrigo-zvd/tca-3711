#!/bin/bash

OPNSENSE_TAG=opnsense

VM_IDS=$(xo-cli rest get vms filter=tags:${OPNSENSE_TAG} --json)

# Remove espaços em branco, colchetes e aspas simples
VM_IDS=$(echo "$VM_IDS" | tr -d '[:space:]' | sed 's/\[//g' | sed 's/\]//g' | sed "s/'//g")

if [ -z "$VM_IDS" ]; then
    echo "Nenhuma VM encontrada com a tag ${OPNSENSE_TAG}. Encerrando o script."
    exit 0
fi

echo "IDs das VMs encontradas: $VM_IDS"

# Agora você pode usar a variável VM_IDS para processar os IDs, se necessário.
# Por exemplo, para iterar sobre os IDs:
#IFS=',' read -r -a id_array <<< "$VM_IDS"
#for vm_id in "${id_array[@]}"; do
#    echo "Processando VM com ID: $vm_id"
#done