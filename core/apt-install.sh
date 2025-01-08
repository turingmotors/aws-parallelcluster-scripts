#!/bin/bash

PACKAGES=$@

apt-get update
apt-get install -y ${PACKAGE_NAME}
