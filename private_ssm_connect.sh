
#!/usr/bin/env bash
KEY_PATH="/home/pablo/terraform-aws/ssh-key.pem"

INST_ID="private_instance_id_1"

if [[ $# -ge 1 ]]; then
  INST_ID="private_instance_id_$1"
fi

PRIV_ID="$(terraform output -raw "$INST_ID")"

#aws ssm start-session --target $(terraform output -raw private_instance_id)
ssh  -o "ProxyCommand=aws ssm start-session  --target %h  --document-name AWS-StartSSHSession \
  --parameters 'portNumber=%p'" -i "$KEY_PATH" "ubuntu@$PRIV_ID"