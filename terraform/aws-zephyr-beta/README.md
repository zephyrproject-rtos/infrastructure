# aws-zephyr-beta

## Overview

This directory contains the Terraform manifests that define the resources for
the staging (test) Kubernetes cluster in the Amazon Web Services (AWS).

The resources defined here are deployed to the `us-east-2` region of the Zephyr
Project main AWS account.

## Deployment

### Overview

Deployment process must be executed locally using the Terraform cloud state
backend, which is managed in the `aws-zephyr-beta` workspace in the Terraform
cloud.

All secrets used during the deployment process are stored in the
`zephyr-secrets` application in the HCP Vault Secrets.

### Host Requirements

The deployment host must have Terraform, Vault (`vlt`), Amazon Web Services CLI
(`aws`) and kubectl installed.

### Initial Deployment

The full cluster deployment process may be executed in whole; however, multiple
retries may be required for the process to complete due to jobs getting stuck
(likely due to internal issues in the AWS).

In terms of CI runner deployment, it is recommended to deploy all cluster
components up to the ARC runner scale set controller; individual runner scale
sets should be manually deployed based on the operational requirements.

```
terraform apply -target=module.zephyr_aws_blueprints.helm_release.arc
```

## Operations

The Elastic Kubernetes Service (EKS) is backed by the EC2 auto-scaling groups,
and node scaling is automatically handled by the cluster autoscaler based on the
requested resources; it is therefore not necessary to manually scale Kubernetes
nodes.

For Continuous Integration (CI) services, GitHub Actions runner scale groups may
need to be put into or taken out of service depending on the operational
requirements (e.g. cloud switch-over for maintenance and emergency fail-over).

### Runner Scale Set Management

To create and activate all runner scale sets in the aws-zephyr-beta deployment:

```
terraform apply \
    -target=helm_release.test_runner_v2_linux_x64_4xlarge_aws \
    -target=helm_release.test_runner_v2_linux_arm64_4xlarge_aws
```

To destroy and deactivate all runner scale sets in the aws-zephyr-beta
deployment:

```
terraform destroy \
    -target=helm_release.test_runner_v2_linux_x64_4xlarge_aws \
    -target=helm_release.test_runner_v2_linux_arm64_4xlarge_aws
```
