
#!/usr/bin/env bash
KEY_PATH="/home/pablo/terraform-aws/ssh-key.pem"
PRIV_ID="$(terraform output -raw private_instance_id)"

#aws ssm start-session --target $(terraform output -raw private_instance_id)
ssh  -o "ProxyCommand=aws ssm start-session  --target %h  --document-name AWS-StartSSHSession \
  --parameters 'portNumber=%p'" -i "$KEY_PATH" "ubuntu@$PRIV_ID"