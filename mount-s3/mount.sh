#!/bin/bash

BUCKET_NAME=$1
TARGET_DIRECTORY=$2
OPTIONS=${3:-"--allow-other"}

# Install mount-s3 command for Ubuntu 22.04
if ! command -v mount-s3 &> /dev/null
then
  apt-get update
  apt-get install libfuse2 -y
  wget -O /tmp/mount-s3.deb https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.deb
  apt-get install /tmp/mount-s3.deb -y
else
  echo "mount-s3 is already installed."
fi

# Needed if --allow-root or --allow-other option is set
if ! grep -q "^user_allow_other" /etc/fuse.conf
then
    echo "user_allow_other" | sudo tee -a /etc/fuse.conf
fi

mkdir -p ${TARGET_DIRECTORY}
chmod 777 ${TARGET_DIRECTORY}
mount-s3 ${BUCKET_NAME} ${TARGET_DIRECTORY} ${OPTIONS}
