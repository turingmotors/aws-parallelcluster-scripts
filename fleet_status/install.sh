#!/bin/bash

SCRIPT_URL="https://raw.githubusercontent.com/turingmotors/aws-parallelcluster-scripts/main/fleet_status/update_compute_fleet_status.sh"
SCRIPT_PATH="/opt/parallelcluster/update_fleet_status.sh"

curl -o ${SCRIPT_PATH} ${SCRIPT_URL}

tee /etc/systemd/system/update_fleet_status_start.service > /dev/null << EOT
[Unit]
Description=Update Fleet Status on startup
After=network.target

[Service]
Type=oneshot
ExecStart=${SCRIPT_PATH} start

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
ExecStart=${SCRIPT_PATH} stop

[Install]
WantedBy=shutdown.target
EOT

systemctl daemon-reload
systemctl enable update_fleet_status_start.service
systemctl enable update_fleet_status_stop.service

exit 0
