#!/bin/bash

if ! command -v ffmpeg &> /dev/null
then
  apt-get -o DPkg::Lock::Timeout=300 update -y
  apt-get -o DPkg::Lock::Timeout=300 install -y ffmpeg
else
  echo "ffmpeg is already installed."
fi
