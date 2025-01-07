#! /bin/bash

# Install mount-s3 command for Ubuntu 22.04
apt-get update
apt-get install libfuse2 -y

wget -O /tmp/mount-s3.deb https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.deb
apt-get install /tmp/mount-s3.deb -y
