#!/bin/bash

SCRIPT_URL="https://raw.githubusercontent.com/turingmotors/aws-parallelcluster-scripts/main/fleet_status/update_compute_fleet_status.sh"
SCRIPT_PATH="/opt/parallelcluster/update_fleet_status.sh"

# スクリプトを取得
curl -o ${SCRIPT_PATH} ${SCRIPT_URL}

# 実行権限を付与
chmod +x ${SCRIPT_PATH}

tee /etc/systemd/system/parallelcluster-compute-fleet-status.service > /dev/null << EOT
[Unit]
Description=Update Fleet Status on startup and shutdown
DefaultDependencies=no
After=network.target
Before=slurmctld.service shutdown.target

[Service]
RemainAfterExit=yes
ExecStart=${SCRIPT_PATH} start
ExecStop=${SCRIPT_PATH} stop

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable parallelcluster-compute-fleet-status.service

exit 0
