# cnx-zephyr-test

## Overview

This directory contains the Terraform manifests that define the resources for
the test Kubernetes cluster in the Centrinix Cloud.

The resources defined here are deployed to the `test` project of the
`zephyrproject` domain in the [Centrinix OpenStack
cloud](https://openstack.centrinix.cloud).

## Deployment

### Overview

Deployment process must be executed locally using the Terraform cloud state
backend, which is managed in the `cnx-zephyr-test` workspace in the Terraform
cloud.

All secrets used during the deployment process are stored in the
`zephyr-secrets` application in the HCP Vault Secrets.

### Host Requirements

The deployment host must have Terraform, Vault (`vlt`), OpenStack Client
(`python-openstackclient`) and kubectl installed.

In addition, the deployment host must have access to the Centrinix Cloud CGN
(carrier grade NAT) network, which requires a special VPN connection, for
connecting to the Kubernetes cluster endpoints.

### Initial Deployment

It is recommended to execute the cluster deployment process in multiple partial
steps to ensure that each component layer is fully deployed before proceeding to
deploy the next layer.

1. Deploy cluster template:

```
terraform apply -target=openstack_containerinfra_clustertemplate_v1.kubernetes_1_23_zephyr_test1
```

2. Deploy Kubernetes cluster:

```
terraform apply -target=openstack_containerinfra_cluster_v1.zephyr_test1
```

3. Deploy node groups:

```
terraform apply -target=openstack_containerinfra_nodegroup_v1.az3_linux_arm64
terraform apply -target=openstack_containerinfra_nodegroup_v1.az3_linux_x64
```

4. Deploy Actions Runner Controller:

```
terraform apply -target=helm_release.arc
```

5. Deploy rest of the resources:

```
terraform apply
```

## Operations

### Node Group Scaling

To list all OpenStack Magnum Kubernetes cluster node groups and their sizes:

```
openstack coe nodegroup list zephyr-test1
```

To scale cluster node groups (default is 1):

```
# Scale all node groups to 3 nodes
openstack coe cluster resize zephyr-test1 --nodegroup az3-linux-x64 3
openstack coe cluster resize zephyr-test1 --nodegroup az3-linux-arm64 3
```

### Runner Scale Set Management

To create and activate all runner scale sets in the cnx-zephyr-test deployment:

```
terraform apply \
    -target=helm_release.test_runner_v2_linux_x64_4xlarge_cnx \
    -target=helm_release.test_runner_v2_linux_arm64_4xlarge_cnx
```

To destroy and deactivate all runner scale sets in the cnx-zephyr-test deployment:

```
terraform destroy \
    -target=helm_release.test_runner_v2_linux_x64_4xlarge_cnx \
    -target=helm_release.test_runner_v2_linux_arm64_4xlarge_cnx
```
