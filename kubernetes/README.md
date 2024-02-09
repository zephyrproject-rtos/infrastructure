# Zephyr Infrastructure Kubernetes Configurations

This directory contains the Kubernetes Infrastructure as Code (IaC)
configuration files for the Zephyr infrastructure components.

## Components

* elastic-stack-main

    * Elastic stack deployment for production use

* elastic-stack-staging

    * Elastic stack deployment for testing

* test-runner

    * A sample auto-scaling GitHub Actions self-hosted runner for testing purposes.

* zephyr-runner

    * GitHub Actions self-hosted runner for production use.
    * To be phased out in the near future.

* zephyr-runner-v2

    * Next generation GitHub Actions self-hosted runner using GitHub runner
      scale sets.
