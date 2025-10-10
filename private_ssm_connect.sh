
#!/usr/bin/env bash
KEY_PATH="/home/pablo/infra/terraform-aws/ssh-key.pem"

INST_INDEX="0"

if [[ $# -ge 1 ]]; then
INST_INDEX=$1
fi
#echo $INST_INDEX
echo "List of asg instances:"
json="$(terraform output -json asg_instance_ids)"
echo $json

#terraform output -json asg_instance_ids
PRIV_ID="$(echo $json | jq -r .[$INST_INDEX])"
# Проверка, что ID не пустой и не null
if [[ -z "$PRIV_ID" || "$PRIV_ID" == "null" ]]; then
  echo "❌ Ошибка: элемент с индексом $INST_INDEX не найден." >&2 # markdown!
  exit 1
fi

echo "💸 Connecting to $PRIV_ID"

#aws ssm start-session --target $PRIV_ID
ssh  -o "ProxyCommand=aws ssm start-session  --target %h  --document-name AWS-StartSSHSession \
#  --parameters 'portNumber=%p'" -i "$KEY_PATH" "ubuntu@$PRIV_ID"