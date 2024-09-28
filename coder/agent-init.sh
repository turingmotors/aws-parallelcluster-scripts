#!/bin/bash

CODER_DIR="/opt/coder"
mkdir -m 777 ${CODER_DIR}

echo "$1" > ${CODER_DIR}/agent_init.sh
chmod +x ${CODER_DIR}/agent_init.sh

tee /etc/systemd/system/coder-agent.service > /dev/null << EOT
[Unit]
Description=Coder Agent
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/bin/bash /opt/coder/agent_init.sh
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable coder-agent.service
systemctl start coder-agent.service

exit 0
