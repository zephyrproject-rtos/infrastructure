#!/usr/bin/env bash

set -eux

# Cache Docker images

## Start Docker daemon
sudo systemctl start docker

## Docker images for Actions Runner Controller
docker pull ghcr.io/actions/actions-runner:2.311.0

## Docker images for zephyr repository CI workflows
docker pull ghcr.io/zephyrproject-rtos/ci-repo-cache:v0.26.6.20231213 # zephyr:main (current)
docker pull ghcr.io/zephyrproject-rtos/ci-repo-cache:v0.26.5.20231213 # zephyr:main (prev)
docker pull ghcr.io/zephyrproject-rtos/ci-repo-cache:v0.26.4.20231213 # zephyr:v3.4-branch
docker pull ghcr.io/zephyrproject-rtos/ci-repo-cache:v0.24.11.20231213 # zephyr:v3.3-branch
docker pull ghcr.io/zephyrproject-rtos/ci-repo-cache:v0.18.4.20231213 # zephyr:v3.3-branch

## Docker images for sdk-ng repository CI workflows
docker pull ghcr.io/zephyrproject-rtos/sdk-build:v1.2.3 # sdk-ng:main

## Stop Docker daemon
sudo systemctl stop docker
