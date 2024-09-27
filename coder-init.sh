#!/bin/bash

CODER_DIR="/opt/coder"
mkdir -m 777 ${CODER_DIR}

echo "$1" > ${CODER_DIR}/token.txt

echo "$2" > ${CODER_DIR}/init_script.sh
chmod +x ${CODER_DIR}/init_script.sh

CODER_AGENT_USER="${3:-ubuntu}"
CODER_AGENT_CMD="export CODER_AGENT_TOKEN_FILE="${CODER_DIR}/token.txt"; nohup ${CODER_DIR}/init_script.sh >/dev/null 2>&1 &"
sudo -u ${CODER_AGENT_USER} bash -c "${CODER_AGENT_CMD}"

echo "@reboot ${CODER_AGENT_CMD}" | sudo -u ${CODER_AGENT_USER} crontab -

exit 0
