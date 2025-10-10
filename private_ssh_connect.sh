#!/usr/bin/env bash
set -euo pipefail

KEY_PATH="/home/pablo/infra/terraform-aws/ssh-key.pem"
INST_INDEX="0"

if [[ $# -ge 1 ]]; then
INST_INDEX=$1
fi

json="$(terraform output -json asg_instance_ids)"
echo "List of asg instances: $json"

#terraform output -json asg_instance_ids
PRIV_ID="$(echo $json | jq -r .[$INST_INDEX])"
# Проверка, что ID не пустой и не null
if [[ -z "$PRIV_ID" || "$PRIV_ID" == "null" ]]; then
  echo "❌ Ошибка: элемент с индексом $INST_INDEX не найден." >&2 # markdown!
  exit 1
fi
echo "💸 Getting IP of $PRIV_ID"
# достаем private_ip
json_ip="$(aws ec2 describe-instances --instance-ids $PRIV_ID --query 'Reservations[].Instances[].PrivateIpAddress')"
PRIV_IP="$(echo $json_ip | jq -r '.[0]')"
echo "Private_ip address: $PRIV_IP"

PUB_IP="$(terraform output -raw public_ip)"

ssh -o "ProxyCommand=ssh -i $KEY_PATH -o IdentitiesOnly=yes -W %h:%p ubuntu@$PUB_IP" -i "$KEY_PATH" -o  IdentitiesOnly=yes  "ubuntu@$PRIV_IP"
