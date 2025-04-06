# Providers
locals {
  k8s_host = "https://deploy1.cluster-a.hzr.zephyrproject.io/k8s/clusters/c-m-gdtt4v8l"
}

provider "kubernetes" {
  host                   = local.k8s_host
  cluster_ca_certificate = base64decode(data.hcp_vault_secrets_app.zephyr_secrets.secrets["hzr_k8s_ca_certificate"])
  token                  = data.hcp_vault_secrets_app.zephyr_secrets.secrets["hzr_k8s_token"]
}

provider "kubectl" {
  host                   = local.k8s_host
  cluster_ca_certificate = base64decode(data.hcp_vault_secrets_app.zephyr_secrets.secrets["hzr_k8s_ca_certificate"])
  token                  = data.hcp_vault_secrets_app.zephyr_secrets.secrets["hzr_k8s_token"]
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = local.k8s_host
    cluster_ca_certificate = base64decode(data.hcp_vault_secrets_app.zephyr_secrets.secrets["hzr_k8s_ca_certificate"])
    token                  = data.hcp_vault_secrets_app.zephyr_secrets.secrets["hzr_k8s_token"]
  }
}

# HashiCorp Vault Secrets zephyr-secrets Vault
data "hcp_vault_secrets_app" "zephyr_secrets" {
  app_name = "zephyr-secrets"
}

# OpenEBS Installation
resource "helm_release" "openebs" {
  name       = "openebs"
  namespace  = "openebs"
  create_namespace = true
  repository = "https://openebs.github.io/charts"
  chart      = "openebs"
  version    = "3.10.0"
  values     = ["${file("../../kubernetes/zephyr-runner-v2/hzr/hzr-openebs/values.yaml")}"]
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
  pattern = "../../kubernetes/zephyr-runner-v2/hzr/hzr-keydb-cache/config.yaml"
}

resource "kubectl_manifest" "keydb_cache_config_manifest" {
  count      = length(data.kubectl_path_documents.keydb_cache_config_manifests.documents)
  yaml_body  = element(data.kubectl_path_documents.keydb_cache_config_manifests.documents, count.index)
  wait       = true
  depends_on = [kubernetes_namespace.keydb_cache]
}

## Persistent Volume Claims
data "kubectl_path_documents" "keydb_cache_pvc_manifests" {
  pattern = "../../kubernetes/zephyr-runner-v2/hzr/hzr-keydb-cache/pvc.yaml"
}

resource "kubectl_manifest" "keydb_cache_pvc_manifest" {
  count      = length(data.kubectl_path_documents.keydb_cache_pvc_manifests.documents)
  yaml_body  = element(data.kubectl_path_documents.keydb_cache_pvc_manifests.documents, count.index)
  wait       = true
  depends_on = [kubernetes_namespace.keydb_cache]
}

## KeyDB Pods
data "kubectl_path_documents" "keydb_cache_keydb_manifests" {
  pattern = "../../kubernetes/zephyr-runner-v2/hzr/hzr-keydb-cache/keydb.yaml"
}

resource "kubectl_manifest" "keydb_cache_keydb_manifest" {
  count      = length(data.kubectl_path_documents.keydb_cache_keydb_manifests.documents)
  yaml_body  = element(data.kubectl_path_documents.keydb_cache_keydb_manifests.documents, count.index)
  wait       = true
  depends_on = [kubernetes_namespace.keydb_cache]
}

## Services
data "kubectl_path_documents" "keydb_cache_services_manifests" {
  pattern = "../../kubernetes/zephyr-runner-v2/hzr/hzr-keydb-cache/services.yaml"
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
    github_app_id = data.hcp_vault_secrets_app.zephyr_secrets.secrets["zephyr_runner_github_app_id"]
    github_app_installation_id = data.hcp_vault_secrets_app.zephyr_secrets.secrets["zephyr_runner_github_app_installation_id"]
    github_app_private_key = data.hcp_vault_secrets_app.zephyr_secrets.secrets["zephyr_runner_github_app_private_key"]
  }
  depends_on = [kubernetes_namespace.arc_runners]
}

## Runner Scale Set Controller Deployment
locals {
  arc_version = "0.11.0"
}

resource "helm_release" "arc" {
  name       = "arc"
  namespace  = "arc-systems"
  create_namespace = true
  chart      = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller"
  version    = local.arc_version
  values     = ["${file("../../kubernetes/zephyr-runner-v2/hzr/hzr-runner-scale-set-controller/values.yaml")}"]
  depends_on = [kubernetes_secret.arc_github_app]
}

## zephyr-runner-v2 Pod Templates
data "kubectl_path_documents" "zephyr_runner_v2_pod_templates_manifests" {
  pattern = "../../kubernetes/zephyr-runner-v2/hzr/zephyr-runner-scale-sets/zephyr-runner-v2-pod-templates.yaml"
}

resource "kubectl_manifest" "zephyr_runner_v2_pod_templates_manifest" {
  count      = length(data.kubectl_path_documents.zephyr_runner_v2_pod_templates_manifests.documents)
  yaml_body  = element(data.kubectl_path_documents.zephyr_runner_v2_pod_templates_manifests.documents, count.index)
  wait       = true
  depends_on = [helm_release.arc]
}

## zephyr-runner-v2-linux-x64-4xlarge-hzr Runner Scale Set Deployment
resource "helm_release" "zephyr_runner_v2_linux_x64_4xlarge_hzr" {
  name       = "zephyr-runner-v2-linux-x64-4xlarge-hzr"
  namespace  = "arc-runners"
  chart      = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
  version    = local.arc_version
  values     = ["${file("../../kubernetes/zephyr-runner-v2/hzr/zephyr-runner-scale-sets/zephyr-runner-v2-linux-x64-4xlarge-hzr/values.yaml")}"]
  depends_on = [kubectl_manifest.zephyr_runner_v2_pod_templates_manifest]
}
