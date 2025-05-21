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
LOG_DIR="/var/log/mountpoint"
WATCHDOG_INTERVAL=10    # systemd WatchdogSec 秒

# --- 2. mount-s3 本体のインストール ---
if ! command -v mount-s3 &>/dev/null; then
  apt-get -o DPkg::Lock::Timeout=300 update -y
  apt-get -o DPkg::Lock::Timeout=300 install -y libfuse2
  wget -O /tmp/mount-s3.deb \
    https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.deb
  apt-get -o DPkg::Lock::Timeout=300 install -y /tmp/mount-s3.deb
else
  echo "mount-s3 is already installed."
fi

# --- 3. FUSE 設定とディレクトリ準備 ---
grep -q "^user_allow_other" /etc/fuse.conf || \
  echo "user_allow_other" | sudo tee -a /etc/fuse.conf

mkdir -p "${TARGET_DIRECTORY}" /scratch "${LOG_DIR}"
chmod 777 "${TARGET_DIRECTORY}" /scratch "${LOG_DIR}"

# --- 4. wrapper スクリプト生成 ---
cat << 'EOF' > "${WRAPPER_PATH}"
#!/bin/bash
set -eu

BUCKET="$1"
TARGET="$2"
shift 2
OPTIONS=("$@")

# 停止フラグ
stop_requested=0
trap 'stop_requested=1; kill "$child" 2>/dev/null' TERM INT

# systemd-notify 用
export NOTIFY_SOCKET

# supervisor ループ
while [ $stop_requested -eq 0 ]; do
  # (1) mount-s3 起動
  /usr/bin/mount-s3 "$BUCKET" "$TARGET" "${OPTIONS[@]}" --foreground &
  child=$!

  # (2) 最初の ready 通知（一度だけ）
  systemd-notify --ready --status="mount-s3 started (PID $child)"

  # (3) child が死ぬまで待機 or stop 要求
  while kill -0 "$child" 2>/dev/null; do
    sleep 1
  done

  # (4) child exit
  wait "$child" || true

  # (5) stop 要求ならループ抜け
  [ $stop_requested -eq 1 ] && break

  # (6) まだサービス継続：ログだけ残して即再起動
  echo "[$(date -Iseconds)] mount-s3 (PID $child) exited; restarting…" | systemd-cat -t mount-s3-supervisor
done

exit 0
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
Description=Mount S3 Bucket via mount-s3 (supervised)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
NotifyAccess=main

# supervisor をフォアグラウンド実行
ExecStart=${WRAPPER_PATH} ${BUCKET_NAME} ${TARGET_DIRECTORY} ${OPTS_JOINED}

# systemctl stop で wrapper に SIGTERM
KillMode=control-group

# 再起動させない（wrapper 内で再起動を制御）
Restart=no

# 必要なら Stop 時にアンマウント
ExecStop=/usr/bin/fusermount -uz /s3/dataset
TimeoutStopSec=20

LimitNOFILE=65536

[Install]
WantedBy=multi-user.target

EOF

# --- 6. systemd 再読み込み＆起動 ---
systemctl daemon-reload
systemctl enable mount-s3.service
systemctl restart mount-s3.service

echo "mount-s3.service installed and started."

