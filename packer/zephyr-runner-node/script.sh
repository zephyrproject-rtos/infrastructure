#!/usr/bin/env bash

set -eux

# ---------------------
# CI Runner Components
# ---------------------

# Save Docker data directory
sudo cp -R /var/lib/docker /var/lib/docker-orig

# Start Docker daemon
sudo systemctl start docker

# Cache CI Docker images
docker pull ghcr.io/zephyrproject-rtos/ci:v0.26.5 # zephyr:main (current)
docker pull ghcr.io/zephyrproject-rtos/ci:v0.26.4 # zephyr:main (prev)
docker pull ghcr.io/zephyrproject-rtos/ci:v0.24.11 # zephyr:v3.3-branch
docker pull ghcr.io/zephyrproject-rtos/ci:v0.24.3 # zephyr:v3.2-branch
docker pull zephyrprojectrtos/ci:v0.18.4 # zephyr:v2.7-branch
docker pull ghcr.io/zephyrproject-rtos/sdk-build:v1.2.3 # sdk-ng:main

# Create pod-cache directory
sudo mkdir -p /pod-cache
sudo chmod 777 /pod-cache
mkdir -p /pod-cache/repos
mkdir -p /pod-cache/tools

# Clone Zephyr repositories
docker run -i --network host -v /pod-cache:/pod-cache ghcr.io/zephyrproject-rtos/ci:v0.26.5 <<-EOF
su user
mkdir -p /pod-cache/repos/zephyrproject
cd /pod-cache/repos/zephyrproject
git clone https://github.com/zephyrproject-rtos/zephyr.git
west init -l zephyr
west update
EOF

# Stop Docker daemon
docker container prune -f
sudo systemctl stop docker

# Create Docker data directory for Docker-in-Docker (DinD)
sudo mv /var/lib/docker /var/lib/docker-dind
sudo mv /var/lib/docker-orig /var/lib/docker

# ---------------------------
# Kubernetes Node Components
# ---------------------------

# Start Docker daemon
sudo systemctl start docker

# Cache Kubernetes pod Docker images
docker pull ghcr.io/actions-runner-controller/actions-runner-controller/actions-runner:latest

# Stop Docker daemon
sudo systemctl stop docker
