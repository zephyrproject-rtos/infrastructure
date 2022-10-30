# Zephyr Infrastructure Kubernetes Configurations

This directory contains the Kubernetes Infrastructure as Code (IaC)
configuration files for the Zephyr infrastructure components.

## Components

* runner-repo-cache

    * Git repository cache to be used in the CI workflows.
    * an EFS-backed dynamically provisioned persistent volume.

* test-runner

    * A sample auto-scaling GitHub Actions self-hosted runner for testing purposes.

* zephyr-runner

    * GitHub Actions self-hosted runner for production use.
