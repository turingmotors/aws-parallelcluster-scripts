#!/bin/bash

BASE_DIR=$(dirname "$0")
source ${BASE_DIR}/venv/bin/activate

# 設定ファイルから TABLE_NAME と REGION を取得
CONFIG_FILE="/etc/parallelcluster/clusterstatusmgtd.conf"

export CLUSTER_NAME=$(grep "^cluster_name" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' ')
export AWS_REGION=$(grep "^region" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' ')

get_fleet_status () {
    pcluster describe-compute-fleet \
        --cluster-name ${CLUSTER_NAME} \
        --region ${AWS_REGION} | jq -r .status
}

update_compute_fleet () {
    local fleet_status=$1
    pcluster update-compute-fleet \
        --cluster-name ${CLUSTER_NAME} \
        --region ${AWS_REGION}  \
        --status ${fleet_status}
}

# アクションの指定（start または stop）
ACTION=$1

if [ "$ACTION" = "start" ]; then
    update_compute_fleet "START_REQUESTED"
elif [ "$ACTION" = "stop" ]; then
    update_compute_fleet "STOP_REQUESTED"
    # 強制停止
    compute_node_ids=$(aws ec2 describe-instances \
        --filters \
            "Name=tag:parallelcluster:cluster-name,Values=${CLUSTER_NAME}" \
            "Name=tag:parallelcluster:node-type,Values=Compute" \
            "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text)
    aws ec2 terminate-instances --instance-ids ${compute_node_ids}
else
    echo "Usage: $0 start|stop"
    exit 1
fi

exit 0
