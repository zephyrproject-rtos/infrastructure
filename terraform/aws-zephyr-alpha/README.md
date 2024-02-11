# aws-zephyr-alpha

## Overview

This directory contains the Terraform manifests that define the resources for
the production Kubernetes cluster in the Amazon Web Services (AWS).

The resources defined here are deployed to the `us-east-2` region of the Zephyr
Project main AWS account.

This cluster hosts the ephemeral GitHub Actions CI runners as well as other
persistent project services such as Elastic Stack.

## Deployment

### Overview

Deployment process must be executed remotely from the `aws-zephyr-alpha`
workspace in the Terraform cloud.

All secrets used during the deployment process are stored in the
`zephyr-secrets` application in the HCP Vault Secrets.

### Host Requirements

The deployment host must have Terraform installed in order to invoke remote
deployment process in the Terraform cloud.


### Methods

The Terraform "plan" process is automatically triggered when a new commit is
pushed to the `main` branch of the infrastructure repository.

After reviewing the generated "plan" and the required changes, the changes may
be applied by triggering "apply" process in the Terraform cloud web UI.

The "plan" and "apply" processes, hereinafter referred to as "deployment
process", may also be manually triggered from the web UI.

In addition, it is also possible to trigger the deployment process from the CLI
using the `terraform` command as with local deployment process; in this case,
the local changes are uploaded to the Terraform cloud workspace and the
requested deployment operation is executed in the Terraform cloud servers.


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
need to put into or taken out of service depending on the operational
requirements (e.g. cloud switch-over for maintenance and emergency fail-over).

### Runner Scale Set Management

To create and activate all runner scale sets in the aws-zephyr-alpha deployment:

```
terraform apply \
    -target=helm_release.zephyr_runner_v2_linux_x64_4xlarge_aws
```

To destroy and deactivate all runner scale sets in the aws-zephyr-alpha
deployment:

```
terraform destroy \
    -target=helm_release.zephyr_runner_v2_linux_x64_4xlarge_aws
```
