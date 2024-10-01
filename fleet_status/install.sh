#!/bin/bash

SCRIPT_URL="https://raw.githubusercontent.com/turingmotors/aws-parallelcluster-scripts/main/fleet_status/update_compute_fleet_status.sh"

curl -o /opt/parallelcluster/update_fleet_status.sh ${SCRIPT_URL}

CODER_DIR="/opt/coder_agent"
mkdir -p ${CODER_DIR}

echo "$1" > ${CODER_DIR}/init.sh
chmod 755 ${CODER_DIR}/init.sh

tee /etc/systemd/system/update_fleet_status_start.service > /dev/null << EOT
[Unit]
Description=Update Fleet Status on startup
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/parallelcluster/update_compute_fleet_status.sh start

[Install]
WantedBy=multi-user.target
EOT

tee /etc/systemd/system/update_fleet_status_stop.service > /dev/null << EOT
[Unit]
Description=Update Fleet Status on shutdown
DefaultDependencies=no
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=/opt/parallelcluster/update_compute_fleet_status.sh stop

[Install]
WantedBy=shutdown.target
EOT

systemctl daemon-reload
systemctl enable update_fleet_status_start.service
systemctl enable update_fleet_status_stop.service

exit 0
