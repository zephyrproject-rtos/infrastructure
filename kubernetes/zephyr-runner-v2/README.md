# zephyr-runner-v2

The zephyr-runner-v2 component provides the Kubernetes-based GitHub Actions
self-hosted runners for use in the Zephyr CI environment.

The YAML files under this directory are the Helm chart configurations for the
Actions Runner Controller runner scale set Helm charts, and are intended to be
referenced by the corresponding resources defined in each cloud deployment
Terraform manifest.

## Directory Structure

* aws: Configurations for AWS cloud zephyr-runner-v2 deployments

    * aws-runner-scale-set-controller: AWS Actions Runner Controller
      configurations
    * aws-test-runner-scale-sets: AWS test runner scale set configurations
    * aws-zephyr-runner-scale-sets: AWS production runner scale set
      configurations

* cnx: Configurations for Centrinix cloud zephyr-runner-v2 deployments

    * cnx-runner-scale-set-controller: Centrinix Actions Runner Controller
      configurations
    * cnx-test-runner-scale-sets: Centrinix test runner scale set configurations
    * cnx-zephyr-runner-scale-sets: Centrinix production runner scale set
      configurations

## Manual Deployment Process

While the Actions Runner Controller Helm chart installations are intended to be
managed using Terraform, it is possible to manually install and manage them for
testing purposes.

### runner-scale-set-controller Deployment

To deploy the Actions Runner Controller runner scale set controller, run the
following commands:

```
helm install arc \
    --namespace arc-systems --create-namespace \
    -f aws/aws-runner-scale-set-controller/values.yaml \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
```

Note that there needs to be only one controller instance per Kubernetes cluster.

### runner-scale-set Deployment

Prior to deploying runner scale sets for zephyr-runner-v2, a Kubernetes secret
containing GitHub app authentication information must be created:

```
kubectl create secret generic arc-github-app \
    --namespace arc-runners \
    --from-literal=github_app_id=123456 \
    --from-literal=github_app_installation_id=1234567890 \
    --from-file=github_app_private_key=github-app-private-key.pem
```

In addition, OpenEBS must be deployed in order to support the dynamic local PVs
required by workflow pods:

```
helm repo add openebs https://openebs.github.io/charts
helm repo update
helm install openebs openebs/openebs --namespace openebs --create-namespace
```

To deploy an Actions Runner Controller runner scale set, run the following
commands:

```
helm install test-runner-v2-linux-x64-4xlarge-aws \
    --namespace arc-runners --create-namespace \
    -f aws/test-runner-scale-sets/test-runner-v2-linux-x64-4xlarge-aws/values.yaml \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

Note that the above commands must be run for every runner scale set deployment.

## Runner Types

| **Name** | **OS** | **Arch** | **vCPU** | **RAM** |
|:---:|:---:|:---:|:---:|:---:|
| zephyr-runner-v2-linux-arm64-xlarge | Linux | AArch64 | 4 | 8G |
| zephyr-runner-v2-linux-arm64-4xlarge | Linux | AArch64 | 16 | 32G |
| zephyr-runner-v2-linux-x64-xlarge | Linux | x86-64 | 4 | 8G |
| zephyr-runner-v2-linux-x64-4xlarge | Linux | x86-64 | 16 | 32G |
| zephyr-runner-v2-linux-multiarch-4xlarge | Linux | AArch64 + x86-64 | 16 | 32G |