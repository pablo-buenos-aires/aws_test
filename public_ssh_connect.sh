#!/usr/bin/env bash
set -euo pipefail
ssh -i ssh-key.pem  ubuntu@$(terraform output -raw public_ip) 

