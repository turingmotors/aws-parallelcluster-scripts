#!/bin/bash

# 設定ファイルから TABLE_NAME と REGION を取得
CONFIG_FILE="/etc/parallelcluster/clusterstatusmgtd.conf"

TABLE_NAME=$(grep "dynamodb_table" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' ')
REGION=$(grep "^region" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' ')

# アクションの指定（start または stop）
ACTION=$1

if [ "$ACTION" == "start" ]; then
    FLEET_STATUS="START_REQUESTED"
elif [ "$ACTION" == "stop" ]; then
    FLEET_STATUS="STOP_REQUESTED"
else
    echo "Usage: $0 start|stop"
    exit 1
fi

get_fleet_status () {
    PYTHON_BIN="/opt/parallelcluster/pyenv/versions/3.9.20/envs/node_virtualenv/bin/python"
    SCRIPT="/opt/parallelcluster/scripts/compute_fleet_status.py"
    $PYTHON_BIN $SCRIPT --table-name ${TABLE_NAME} --region ${REGION} --action get | jq -r .status
}

update_fleet_status () {
    aws dynamodb update-item \
        --table-name ${TABLE_NAME} \
        --key '{"Id": {"S": "COMPUTE_FLEET"}}' \
        --update-expression "SET #d.#updated_time = :t, #d.#status = :s" \
        --expression-attribute-names '{"#d": "Data", "#updated_time": "lastStatusUpdatedTime", "#status": "status"}' \
        --expression-attribute-values '{
            ":t": {"S": "'"$(date --utc +"%Y-%m-%d %H:%M:%S UTC")"'"},
            ":s": {"S": "'"${FLEET_STATUS}"'"}
        }' \
        --return-values ALL_NEW \
        --region ${REGION}
}

# DynamoDB Table 上のステータスを更新
update_fleet_status

# タイムアウトとチェック間隔の設定
MAX_WAIT_TIME=120  # 最大待機時間（秒）
INTERVAL=10        # チェック間隔（秒）
elapsed_time=0

# ステータスが STOPPED になるまで待機
if [ "$ACTION" == "stop" ]; then
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
fi

exit 0
