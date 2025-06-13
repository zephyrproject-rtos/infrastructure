# Zephyr Infrastructure Terraform Configurations

This directory contains the Terraform Infrastructure as Code (IaC)
configuration files for the Zephyr infrastructure components.

## Components

* zephyr-aws-blueprints

    * Amazon Web Services-based Kubernetes cluster configurations template.

* aws-zephyr-alpha

    * Production Kubernetes cluster for Zephyr infrastructure services.
    * Hosted on Amazon Web Services.
    * Terraform plan and applies are remotely executed on the Terraform Cloud.

* cnx-zephyr-ci

    * Production Kubernetes cluster for Zephyr infrastructure services.
    * Hosted on Centrinix Cloud.
    * Terraform plan and applies are locally executed with Terraform Cloud state backend.

* cnx-zephyr-test

    * Staging Kubernetes cluster for Zephyr infrastructure services.
    * Hosted on Centrinix Cloud.
    * Terraform plan and applies are locally executed with Terraform Cloud state backend.

* hzr-ci-main

    * Production Kubernetes cluster for Zephyr infrastructure services.
    * Hosted on Hetzner Rancher Server.
    * Terraform plan and applies are locally executed with Terraform Cloud state backend.
