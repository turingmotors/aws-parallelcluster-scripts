#!/bin/bash

# 設定ファイルから TABLE_NAME と REGION を取得
CONFIG_FILE="/etc/parallelcluster/clusterstatusmgtd.conf"

CLUSTER_NAME=$(grep "^cluster_name" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' ')
REGION=$(grep "^region" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' ')

source /opt/pcluster/bin/activate

get_fleet_status () {
    pcluster describe-compute-fleet \
        --cluster-name ${CLUSTER_NAME} \
        --region ${REGION} | jq -r .status
}

update_compute_fleet () {
    local fleet_status=$1
    pcluster update-compute-fleet \
        --cluster-name ${CLUSTER_NAME} \
        --region ${REGION}  \
        --status ${fleet_status}
}

# アクションの指定（start または stop）
ACTION=$1

if [ "$ACTION" = "start" ]; then
    update_compute_fleet "START_REQUESTED"
elif [ "$ACTION" = "stop" ]; then
    update_compute_fleet "STOP_REQUESTED"
    # タイムアウトとチェック間隔の設定
    MAX_WAIT_TIME=120  # 最大待機時間（秒）
    INTERVAL=10        # チェック間隔（秒）
    elapsed_time=0
    # 待機
    while [ $elapsed_time -lt $MAX_WAIT_TIME ]; do
        STATUS=$(get_fleet_status)
        if [ "$STATUS" == "STOPPED" ]; then
            echo "Fleet status is now $STATUS"
            break
        else
            echo "Current fleet status is $STATUS. Waiting..."
            sleep $INTERVAL  # チェック間隔待機
            elapsed_time=$((elapsed_time + INTERVAL))
        fi
    done
else
    echo "Usage: $0 start|stop"
    exit 1
fi

exit 0
