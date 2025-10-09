#!/usr/bin/env bash
set -euo pipefail

KEY_PATH="/home/pablo/terraform-aws/ssh-key.pem"
PRIV_IP="private_ip_1"

# if [[ $# -ge 1 ]]; then
#PRIV_IP="private_ip_$1"
# fi

PUB="$(terraform output -raw public_ip)"
PRIV="$(terraform output -raw "$PRIV_IP")"

ssh -o "ProxyCommand=ssh -i $KEY_PATH -o IdentitiesOnly=yes -W %h:%p ubuntu@$PUB" -i "$KEY_PATH" -o  IdentitiesOnly=yes  "ubuntu@$PRIV"
