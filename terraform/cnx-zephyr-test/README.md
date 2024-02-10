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

### Host Requirements

The deployment host must have Terraform, OpenStack Client
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

4. Deploy rest of the resources:

```
terraform apply
```
