#!/usr/bin/env bash
set -euo pipefail

KEY_PATH="/home/pablo/terraform-aws/ssh-key.pem"


PUB="$(terraform output -raw public_ip)"
PRIV="$(terraform output -raw private_ip)"


ssh -o "ProxyCommand=ssh -i $KEY_PATH -o IdentitiesOnly=yes -W %h:%p ubuntu@$PUB" -i "$KEY_PATH" -o \ IdentitiesOnly=yes  "ubuntu@$PRIV"
