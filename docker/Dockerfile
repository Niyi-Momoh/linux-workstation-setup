# A reproducible development image built by the same playbook as a physical workstation.
FROM ubuntu:24.04

ARG INSTALL_ROS=false
ARG INSTALL_KUBERNETES_TOOLS=false
ENV DEBIAN_FRONTEND=noninteractive

COPY ansible.cfg /opt/setup/ansible.cfg
COPY inventory /opt/setup/inventory
COPY playbooks /opt/setup/playbooks
COPY roles /opt/setup/roles
COPY scripts/workstation-verify /usr/local/bin/workstation-verify
COPY docker/start-jupyter /usr/local/bin/start-jupyter

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends python3-venv ca-certificates; \
    python3 -m venv /opt/ansible; \
    /opt/ansible/bin/pip install --quiet 'ansible>=11,<14'; \
    cd /opt/setup; \
    /opt/ansible/bin/ansible-playbook playbooks/site.yml \
        -e container_image=true -e workstation_user=dev \
        -e install_ros="${INSTALL_ROS}" \
        -e install_kubernetes_tools="${INSTALL_KUBERNETES_TOOLS}"; \
    rm -rf /opt/ansible /opt/setup /root/.ansible /home/dev/.ansible /root/.cache /home/dev/.cache; \
    rm -f /home/dev/.bashrc.*~ /home/dev/.tmux.conf.*~; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/*; \
    install -d -o 1000 -g 1000 /home/dev/workspace

USER 1000:1000
WORKDIR /home/dev/workspace
ENV HOME=/home/dev \
    JUPYTER_RUNTIME_DIR=/tmp/jupyter/runtime \
    JUPYTER_DATA_DIR=/tmp/jupyter/data \
    JUPYTER_CONFIG_DIR=/tmp/jupyter/config \
    PATH=/home/dev/.local/bin:/home/dev/.venvs/ml/bin:/usr/local/bin:/usr/bin:/bin
EXPOSE 8888
HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8888/api || exit 1
CMD ["/usr/local/bin/start-jupyter"]
