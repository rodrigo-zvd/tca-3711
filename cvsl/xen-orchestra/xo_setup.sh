#!/bin/bash
xo-cli register --allowUnauthorized http://xen-orchestra:80 admin@admin.net admin 
xo-cli server.add host=${XCP_MASTER_IP} username="${XCP_USER}" password="${XCP_PASSWORD}" autoConnect=true allowUnauthorized=true
ADMIN_USER_ID=$(xo-cli user.getAll --json | jq -r '.[] | select(.email == "admin@admin.net") | .id')
xo-cli user.set id=${ADMIN_USER_ID} email=${XOA_USER} password=${XOA_PASSWORD}
# sleep 3600
# # xo-cli list-commands | grep -i user
