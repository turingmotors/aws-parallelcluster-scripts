#!/bin/bash

# 設定ファイルから TABLE_NAME と REGION を取得
CONFIG_FILE="/etc/parallelcluster/clusterstatusmgtd.conf"

TABLE_NAME=$(grep "dynamodb_table" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' ')
REGION=$(grep "^region" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' ')

get_fleet_status () {
    local python="/opt/parallelcluster/pyenv/versions/3.9.20/envs/node_virtualenv/bin/python"
    local script="/opt/parallelcluster/scripts/compute_fleet_status.py"
    $python $script --table-name ${TABLE_NAME} --region ${REGION} --action get | jq -r .status
}

update_fleet_status () {
    local fleet_status=$1
    aws dynamodb update-item \
        --table-name ${TABLE_NAME} \
        --key '{"Id": {"S": "COMPUTE_FLEET"}}' \
        --update-expression "SET #d.#updated_time = :t, #d.#status = :s" \
        --expression-attribute-names '{"#d": "Data", "#updated_time": "lastStatusUpdatedTime", "#status": "status"}' \
        --expression-attribute-values '{
            ":t": {"S": "'"$(date --utc "+%Y-%m-%d %H:%M:%S.%6N%:z")"'"},
            ":s": {"S": "'"${fleet_status}"'"}
        }' \
        --return-values ALL_NEW \
        --region ${REGION}

    # エラーハンドリング
    if [ $? -ne 0 ]; then
        echo "Failed to update fleet status to ${fleet_status}"
        exit 1
    fi
}

# アクションの指定（start または stop）
ACTION=$1

if [ "$ACTION" = "start" ]; then
    current_status=$(get_fleet_status)
    if [ "$current_status" != "RUNNING" ]; then
        update_fleet_status "START_REQUESTED"
    fi
elif [ "$ACTION" = "stop" ]; then
    update_fleet_status "STOP_REQUESTED"
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
