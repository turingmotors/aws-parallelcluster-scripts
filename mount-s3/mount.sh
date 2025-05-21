#!/bin/bash
set -euxo pipefail

# 引数チェック
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <BUCKET_NAME> <TARGET_DIRECTORY> [OPTIONS...]"
  exit 1
fi

# --- 1. パラメータ分解 ---
BUCKET_NAME="$1"
TARGET_DIRECTORY="$2"
shift 2
OPTIONS=("$@")

# 固定パラメータ
WRAPPER_PATH="/usr/local/bin/mount-s3-wrapper.sh"
SERVICE_PATH="/etc/systemd/system/mount-s3.service"
WATCHDOG_INTERVAL=10    # systemd WatchdogSec 秒

# --- 2. mount-s3 本体のインストール ---
if ! command -v mount-s3 &>/dev/null; then
  apt-get -o DPkg::Lock::Timeout=300 update -y
  apt-get -o DPkg::Lock::Timeout=300 install -y libfuse2 dos2unix
  wget -O /tmp/mount-s3.deb \
    https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.deb
  apt-get -o DPkg::Lock::Timeout=300 install -y /tmp/mount-s3.deb
else
  echo "mount-s3 is already installed."
fi

# --- 3. FUSE 設定とディレクトリ準備 ---
grep -q "^user_allow_other" /etc/fuse.conf || \
  echo "user_allow_other" | sudo tee -a /etc/fuse.conf

mkdir -p "${TARGET_DIRECTORY}" /scratch
chmod 777 "${TARGET_DIRECTORY}" /scratch

# --- 4. wrapper スクリプト生成 ---
cat << 'EOF' > "${WRAPPER_PATH}"
#!/bin/bash
set -eu

BUCKET_NAME="$1"
TARGET_DIRECTORY="$2"
shift 2
OPTIONS=("$@")

# (1) mount-s3 をフォアグラウンド実行
exec /usr/bin/mount-s3 "${BUCKET_NAME}" "${TARGET_DIRECTORY}" "${OPTIONS[@]}" --foreground &
CHILD=$!

# (2) systemd に ready 通知
export NOTIFY_SOCKET
systemd-notify --ready --status="mount-s3 started (PID $CHILD)"

# (3) systemd からのシグナルを子プロセスに転送
trap 'kill -TERM $CHILD 2>/dev/null' TERM INT

# (4) 定期的に watchdog 通知
while kill -0 "$CHILD" 2>/dev/null; do
  systemd-notify WATCHDOG=1 --status="alive: ${CHILD}"
  sleep 5
done

wait "$CHILD"
exit $?
EOF

chmod +x "${WRAPPER_PATH}"

# --- 5. systemd ユニット生成 ---
# OPTIONS をそのまま ExecStart に渡すために join
OPTS_JOINED=""
for o in "${OPTIONS[@]}"; do
  OPTS_JOINED+=" ${o}"
done

cat << EOF > "${SERVICE_PATH}"
[Unit]
Description=Mount S3 Bucket via mount-s3 (with watchdog)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
NotifyAccess=main
ExecStart=${WRAPPER_PATH} ${BUCKET_NAME} ${TARGET_DIRECTORY}${OPTS_JOINED}

WatchdogSec=${WATCHDOG_INTERVAL}s
Restart=always
StartLimitBurst=5
ExecStop=/bin/true
RestartSec=2s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# --- 6. systemd 再読み込み＆起動 ---
systemctl daemon-reload
systemctl enable mount-s3.service
systemctl restart mount-s3.service

echo "mount-s3.service installed and started."

