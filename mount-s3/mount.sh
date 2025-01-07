#! /bin/bash

BUCKET_NAME=$1
TARGET_DIRECTORY=$2
OPTIONS=$3

# Allow other users to access mount
# Needed if --allow-root or --allow-other option is set
if ! grep -q "^user_allow_other" /etc/fuse.conf
then
    echo "user_allow_other" | sudo tee -a /etc/fuse.conf
fi

mkdir -p ${TARGET_DIRECTORY}
chmod 777 ${TARGET_DIRECTORY}
mount-s3 ${OPTIONS} ${BUCKET_NAME} ${TARGET_DIRECTORY}
