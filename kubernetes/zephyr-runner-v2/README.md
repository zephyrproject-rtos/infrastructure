# zephyr-runner-v2

The zephyr-runner-v2 component provides the Kubernetes-based GitHub Actions
self-hosted runners for use in the Zephyr CI environment.

The YAML files under this directory are the Helm chart configurations for the
Actions Runner Controller runner scale set Helm charts, and are intended to be
referenced by the corresponding resources defined in each cloud deployment
Terraform manifest.

## Directory Structure

> [!NOTE]
> AWS-hosted Actions Runner Controller deployment has been phased out and
> is no longer maintained.

* aws: Configurations for AWS cloud zephyr-runner-v2 deployments (obsolete)

    * aws-openebs: AWS OpenEBS configurations

* cnx: Configurations for Centrinix cloud zephyr-runner-v2 deployments

    * cnx-privileged: Centrinix Magnum Kubernetes cluster permissive pod security policy
    * cnx-openebs: Centrinix OpenEBS configurations
    * cnx-openebs-rawfile-localpv: Centrinix OpenEBS LocalPV configurations
    * cnx-keydb-cache: Centrinix KeyDB compilation cache configurations
    * cnx-runner-scale-set-controller: Centrinix Actions Runner Controller
      configurations
    * test-runner-scale-sets: Centrinix test runner scale set configurations
    * zephyr-runner-scale-sets: Centrinix production runner scale set
      configurations

* hzr: Configurations for Hetzner zephyr-runner-v2 deployments

    * hzr-openebs: Hetzner OpenEBS configurations
    * hzr-keydb-cache: Hetzner KeyDB compilation cache configurations
    * hzr-eclair-sentinel: Hetzner Sentinel license server for ECLAIR
    * hzr-runner-scale-set-controller: Hetzner Actions Runner Controller configurations
    * test-runner-scale-sets: Hetzner test runner scale set configurations
    * zephyr-runner-scale-sets: Hetzner production runner scale set configurations


## Manual Deployment Process

While the Actions Runner Controller Helm chart installations are intended to be
managed using Terraform, it is possible to manually install and manage them for
testing purposes.

### Pod Security Policy Configuration

`PodSecurityPolicy` admission controller is enabled by default on both AWS
Elastic Kubernetes Service (EKS) and Centrinix OpenStack Magnum Kubernetes
clusters by default.

In the AWS EKS Kubernetes cluster, AWS creates a default pod security policy
that allows full unrestricted access to Pod features from all authenticated
users.

This is not done by default in the Centrinix Magnum OpenStack cluster and it is
necessary to create a pod security policy that allows all authenticated users to
access Pod features:

```
kubectl apply -f cnx/cnx-privileged/privileged-podsecuritypolicy.yaml
```

### OpenEBS Deployment

OpenEBS must be deployed in order to support the dynamic local PVs required by
workflow pods.

To deploy OpenEBS, run the following commands:

```
helm repo add openebs https://openebs.github.io/charts
helm repo update
helm install openebs openebs/openebs \
    --namespace openebs --create-namespace \
    -f hzr/hzr-openebs/values.yaml
```

### KeyDB Deployment

KeyDB Redis server stores ccache compilation cache data.

To deploy KeyDB, run the following commands:

```
kubectl apply -f hzr/hzr-keydb-cache/config.yaml
kubectl apply -f hzr/hzr-keydb-cache/pvc.yaml
kubectl apply -f hzr/hzr-keydb-cache/services.yaml
kubectl apply -f hzr/hzr-keydb-cache/keydb.yaml
```

### ECLAIR Sentinel License Server Deployment

ECLAIR Sentinel license server provides floating license for the CI workflows
running ECLAIR static code analysis tool.

Prior to deploying the ECLAIR Sentinel license server, a Docker registry secret
for accessing the private `eclair-sentinel` Docker image must be created:

```
kubectl create secret docker-registry ghcr-eclair-sentinel \
    --docker-server=ghcr.io \
    --docker-username zephyrbot \
    --docker-password ghp_GITHUB_TOKEN
```

To deploy the ECLAIR Sentinel license server, run the following commands:

```
kubectl apply -f hzr/hzr-eclair-sentinel/config.yaml
kubectl apply -f hzr/hzr-eclair-sentinel/service.yaml
kubectl apply -f hzr/hzr-eclair-sentinel/sentinel.yaml
```

The ECLAIR Sentinel Admin Control Center (ACC) can be accessed from a local
machine as follows:

```
kubectl -n eclair-sentinel port-forward service/sentinel-server 20000:1947
# go to http://localhost:20000
```

### runner-scale-set-controller Deployment

To deploy the Actions Runner Controller runner scale set controller, run the
following commands:

```
helm install arc \
    --namespace arc-systems --create-namespace \
    -f hzr/hzr-runner-scale-set-controller/values.yaml \
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

To deploy an Actions Runner Controller runner scale set, run the following
commands:

```
# Create pod template
kubectl apply -f hzr/test-runner-scale-sets/test-runner-v2-pod-templates.yaml

# Install runner scale set Helm chart
helm install test-runner-v2-linux-x64-4xlarge-hzr \
    --namespace arc-runners --create-namespace \
    -f hzr/test-runner-scale-sets/test-runner-v2-linux-x64-4xlarge-hzr/values.yaml \
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
