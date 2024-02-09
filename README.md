# Zephyr Project Infrastructure Management

This is the central repository for tracking Zephyr Project infrastructure
management tasks and storing infrastructure-as-code (IaC) workflow and manifest
files.

## Repository Structure

* terraform

    * Terraform manifests defining base layer infrastructure components such as
      networks, server nodes and clusters.
    * Deployment process and states are managed in the Terraform Cloud.

* kubernetes

    * Kubernetes manifests defining Kubernetes-based infrastructure resources.
    * Most resources defined by these manifests are automatically deployed via
      Terraform and GitHub Actions workflows.
    * Some manifests defining test-only resources may be manually deployed as
      needed.

* packer

    * Packer scripts used for building node machine images.
    * Mainly used for building AMIs for use in the AWS.
