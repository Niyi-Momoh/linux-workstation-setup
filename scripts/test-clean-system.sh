#!/usr/bin/env bash
# Run inside a fresh ubuntu:24.04 container with this repository mounted at /src.
# It proves that setup works from nothing and that a second run changes nothing.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export ANSIBLE_CONFIG=/src/ansible.cfg
args=(-e workstation_user=dev -e install_desktop=false -e install_docker=true "$@")

apt-get update -qq
apt-get install -y -qq --no-install-recommends python3-venv ca-certificates >/dev/null
python3 -m venv /opt/ansible
/opt/ansible/bin/pip install --quiet 'ansible>=11,<14'
useradd -m -u 1000 -s /bin/bash dev
cd /src

/opt/ansible/bin/ansible-playbook playbooks/site.yml "${args[@]}" | tee /tmp/first.log
/opt/ansible/bin/ansible-playbook playbooks/site.yml "${args[@]}" | tee /tmp/second.log

if ! grep -Eq 'changed=0 .*failed=0' /tmp/second.log; then
  echo "FAIL: the second run was not idempotent" >&2
  exit 1
fi
echo "PASS: the second run changed nothing"
su - dev -c "EXPECT_ROS=${EXPECT_ROS:-0} EXPECT_KUBECTL=${EXPECT_KUBECTL:-0} /src/scripts/workstation-verify"
