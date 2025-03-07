#!/bin/bash

set -exo pipefail

PACKAGES=$@

apt-get -o DPkg::Lock::Timeout=300 update -y
apt-get -o DPkg::Lock::Timeout=300 install -y ${PACKAGES}
