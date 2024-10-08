#!/bin/bash

BASE_DIR="/opt/pcluster"

# Install ParallelCluster CLI
python3 -m pip install --user --upgrade virtualenv
python3 -m virtualenv ${BASE_DIR}/venv
${BASE_DIR}/venv/bin/pip3 install aws-parallelcluster

SCRIPT_URL="https://raw.githubusercontent.com/turingmotors/aws-parallelcluster-scripts/main/fleet/update_compute_fleet.sh"
SCRIPT_PATH="${BASE_DIR}/update_compute_fleet.sh"

# スクリプトを取得
curl -o ${SCRIPT_PATH} ${SCRIPT_URL}

# 実行権限を付与
chmod +x ${SCRIPT_PATH}

tee /etc/systemd/system/parallelcluster-compute-fleet-status.service > /dev/null << EOT
[Unit]
Description=Update Fleet Status on startup and shutdown
After=network-online.target
Before=supervisord.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${SCRIPT_PATH} start
ExecStop=${SCRIPT_PATH} stop
TimeoutStopSec=120s

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable parallelcluster-compute-fleet-status.service
systemctl start parallelcluster-compute-fleet-status.service

exit 0
