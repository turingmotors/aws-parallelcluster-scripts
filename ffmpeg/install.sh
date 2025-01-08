#!/bin/bash

if ! command -v ffmpeg &> /dev/null
then
  apt-get update
  apt-get install ffmpeg -y
else
  echo "ffmpeg is already installed."
fi
