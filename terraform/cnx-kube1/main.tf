# Providers
locals {
  k8s_host = "https://deploy1.dmz.zephyr-ci.centrinix.cloud/k8s/clusters/c-m-6zx64knl"
}

provider "kubernetes" {
  host                   = local.k8s_host
  cluster_ca_certificate = base64decode(local.zephyr_secrets.cnx_k8s_ca_certificate)
  token                  = local.zephyr_secrets.cnx_k8s_token
}

provider "kubectl" {
  host                   = local.k8s_host
  cluster_ca_certificate = base64decode(local.zephyr_secrets.cnx_k8s_ca_certificate)
  token                  = local.zephyr_secrets.cnx_k8s_token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = local.k8s_host
    cluster_ca_certificate = base64decode(local.zephyr_secrets.cnx_k8s_ca_certificate)
    token                  = local.zephyr_secrets.cnx_k8s_token
  }
}

provider "aws" {
  region = "us-east-1"
}

# AWS Secrets Manager terraform-zephyr-secrets Secret
data "aws_secretsmanager_secret_version" "terraform-zephyr-secrets" {
  secret_id = "terraform-zephyr-secrets"
}

locals {
  zephyr_secrets = jsondecode(data.aws_secretsmanager_secret_version.terraform-zephyr-secrets.secret_string)
}

# OpenEBS Installation
resource "helm_release" "openebs" {
  name       = "openebs"
  namespace  = "openebs"
  create_namespace = true
  repository = "https://openebs.github.io/charts"
  chart      = "openebs"
  version    = "3.10.0"
  values     = ["${file("../../kubernetes/zephyr-runner-v2/cnx/cnx-openebs/values.yaml")}"]
}

# KeyDB Redis Cache Installation
## keydb-cache Namespace
resource "kubernetes_namespace" "keydb_cache" {
  metadata {
    name = "keydb-cache"
  }
  lifecycle {
    ignore_changes = [metadata]
  }
  depends_on = [helm_release.openebs]
}

## Configurations
data "kubectl_path_documents" "keydb_cache_config_manifests" {
  pattern = "../../kubernetes/zephyr-runner-v2/cnx/cnx-keydb-cache/config.yaml"
}

resource "kubectl_manifest" "keydb_cache_config_manifest" {
  count      = length(data.kubectl_path_documents.keydb_cache_config_manifests.documents)
  yaml_body  = element(data.kubectl_path_documents.keydb_cache_config_manifests.documents, count.index)
  wait       = true
  depends_on = [kubernetes_namespace.keydb_cache]
}

## Persistent Volume Claims
data "kubectl_path_documents" "keydb_cache_pvc_manifests" {
  pattern = "../../kubernetes/zephyr-runner-v2/cnx/cnx-keydb-cache/pvc.yaml"
}

resource "kubectl_manifest" "keydb_cache_pvc_manifest" {
  count      = length(data.kubectl_path_documents.keydb_cache_pvc_manifests.documents)
  yaml_body  = element(data.kubectl_path_documents.keydb_cache_pvc_manifests.documents, count.index)
  wait       = true
  depends_on = [kubernetes_namespace.keydb_cache]
}

## KeyDB Pods
data "kubectl_path_documents" "keydb_cache_keydb_manifests" {
  pattern = "../../kubernetes/zephyr-runner-v2/cnx/cnx-keydb-cache/keydb.yaml"
}

resource "kubectl_manifest" "keydb_cache_keydb_manifest" {
  count      = length(data.kubectl_path_documents.keydb_cache_keydb_manifests.documents)
  yaml_body  = element(data.kubectl_path_documents.keydb_cache_keydb_manifests.documents, count.index)
  wait       = true
  depends_on = [kubernetes_namespace.keydb_cache]
}

## Services
data "kubectl_path_documents" "keydb_cache_services_manifests" {
  pattern = "../../kubernetes/zephyr-runner-v2/cnx/cnx-keydb-cache/services.yaml"
}

resource "kubectl_manifest" "keydb_cache_services_manifest" {
  count      = length(data.kubectl_path_documents.keydb_cache_services_manifests.documents)
  yaml_body  = element(data.kubectl_path_documents.keydb_cache_services_manifests.documents, count.index)
  wait       = true
  depends_on = [kubernetes_namespace.keydb_cache]
}

# Actions Runner Controller (ARC) Installation
## arc-runners Namespace
resource "kubernetes_namespace" "arc_runners" {
  metadata {
    name = "arc-runners"
  }
  lifecycle {
    ignore_changes = [metadata]
  }
  depends_on = [helm_release.openebs]
}

## GitHub App Secret
resource "kubernetes_secret" "arc_github_app" {
  metadata {
    name = "arc-github-app"
    namespace = "arc-runners"
  }
  data = {
    github_app_id = local.zephyr_secrets.zephyr_runner_github_app_id
    github_app_installation_id = local.zephyr_secrets.zephyr_runner_github_app_installation_id
    github_app_private_key = local.zephyr_secrets.zephyr_runner_github_app_private_key
  }
  depends_on = [kubernetes_namespace.arc_runners]
}

## Runner Scale Set Controller Deployment
locals {
  arc_version = "0.14.2"
}

resource "helm_release" "arc" {
  name       = "arc"
  namespace  = "arc-systems"
  create_namespace = true
  chart      = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller"
  version    = local.arc_version
  values     = ["${file("../../kubernetes/zephyr-runner-v2/cnx/cnx-runner-scale-set-controller/values.yaml")}"]
  depends_on = [kubernetes_secret.arc_github_app]
}

## zephyr-runner-v2 Pod Templates
data "kubectl_path_documents" "zephyr_runner_v2_pod_templates_manifests" {
  pattern = "../../kubernetes/zephyr-runner-v2/cnx/zephyr-runner-scale-sets/zephyr-runner-v2-pod-templates.yaml"
}

resource "kubectl_manifest" "zephyr_runner_v2_pod_templates_manifest" {
  count      = length(data.kubectl_path_documents.zephyr_runner_v2_pod_templates_manifests.documents)
  yaml_body  = element(data.kubectl_path_documents.zephyr_runner_v2_pod_templates_manifests.documents, count.index)
  wait       = true
  depends_on = [helm_release.arc]
}

## zephyr-runner-v2-linux-x64-4xlarge-cnx Runner Scale Set Deployment
# resource "helm_release" "zephyr_runner_v2_linux_x64_4xlarge_cnx" {
#   name       = "zephyr-runner-v2-linux-x64-4xlarge-cnx"
#   namespace  = "arc-runners"
#   chart      = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
#   version    = local.arc_version
#   values     = ["${file("../../kubernetes/zephyr-runner-v2/cnx/zephyr-runner-scale-sets/zephyr-runner-v2-linux-x64-4xlarge-cnx/values.yaml")}"]
#   depends_on = [kubectl_manifest.zephyr_runner_v2_pod_templates_manifest]
# }

## zephyr-runner-v2-linux-arm64-4xlarge-cnx Runner Scale Set Deployment
resource "helm_release" "zephyr_runner_v2_linux_arm64_4xlarge_cnx" {
  name       = "zephyr-runner-v2-linux-arm64-4xlarge-cnx"
  namespace  = "arc-runners"
  chart      = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
  version    = local.arc_version
  values     = ["${file("../../kubernetes/zephyr-runner-v2/cnx/zephyr-runner-scale-sets/zephyr-runner-v2-linux-arm64-4xlarge-cnx/values.yaml")}"]
  depends_on = [kubectl_manifest.zephyr_runner_v2_pod_templates_manifest]
}
