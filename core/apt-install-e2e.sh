#!/bin/bash

set -exo pipefail

PACKAGES=$@

apt-get -y update
apt-get -y install ffmpeg ${PACKAGES}
