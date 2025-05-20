#!/bin/bash

BUCKET_NAME=$1
TARGET_DIRECTORY=$2
OPTIONS="${@:3}"

# Install mount-s3 command for Ubuntu 22.04
if ! command -v mount-s3 &> /dev/null
then
  apt-get -o DPkg::Lock::Timeout=300 update -y
  apt-get -o DPkg::Lock::Timeout=300 install -y libfuse2
  wget -O /tmp/mount-s3.deb https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.deb
  apt-get -o DPkg::Lock::Timeout=300 install -y /tmp/mount-s3.deb
else
  echo "mount-s3 is already installed."
fi

# Needed if --allow-root or --allow-other option is set
if ! grep -q "^user_allow_other" /etc/fuse.conf
then
    echo "user_allow_other" | sudo tee -a /etc/fuse.conf
fi

# Create cache directory
mkdir -p /scratch
chmod 777 /scratch

# Create mount target directory
mkdir -p ${TARGET_DIRECTORY}
chmod 777 ${TARGET_DIRECTORY}

sudo tee /etc/systemd/system/mount-s3.service << EOF
[Unit]
Description=Mount S3 Bucket via mount-s3
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStart=/usr/bin/mount-s3 ${BUCKET_NAME} ${TARGET_DIRECTORY} ${OPTIONS}
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mount-s3.service
sudo systemctl start mount-s3.service
