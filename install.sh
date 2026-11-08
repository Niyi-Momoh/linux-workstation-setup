#!/usr/bin/env bash
# Bootstrap Ansible in a private environment, then configure this computer.
set -euo pipefail
cd "$(dirname "$0")"

if [[ "$(id -u)" == 0 ]]; then
  echo "Run this from your normal account. It will ask for sudo when needed." >&2
  exit 1
fi
sudo apt-get update
sudo apt-get install -y python3-venv
python3 -m venv .ansible-env
.ansible-env/bin/pip install --quiet 'ansible>=11,<14'
.ansible-env/bin/ansible-playbook playbooks/site.yml --ask-become-pass "$@"
