# Providers
provider "openstack" {
  region      = "Gumi"
  domain_name = "zephyrproject"
  tenant_name = "test"
}

provider "kubernetes" {
  host                   = openstack_containerinfra_cluster_v1.zephyr_test1.kubeconfig.host
  cluster_ca_certificate = openstack_containerinfra_cluster_v1.zephyr_test1.kubeconfig.cluster_ca_certificate
  client_certificate     = openstack_containerinfra_cluster_v1.zephyr_test1.kubeconfig.client_certificate
  client_key             = openstack_containerinfra_cluster_v1.zephyr_test1.kubeconfig.client_key
}

provider "kubectl" {
  host                   = openstack_containerinfra_cluster_v1.zephyr_test1.kubeconfig.host
  cluster_ca_certificate = openstack_containerinfra_cluster_v1.zephyr_test1.kubeconfig.cluster_ca_certificate
  client_certificate     = openstack_containerinfra_cluster_v1.zephyr_test1.kubeconfig.client_certificate
  client_key             = openstack_containerinfra_cluster_v1.zephyr_test1.kubeconfig.client_key
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = openstack_containerinfra_cluster_v1.zephyr_test1.kubeconfig.host
    cluster_ca_certificate = openstack_containerinfra_cluster_v1.zephyr_test1.kubeconfig.cluster_ca_certificate
    client_certificate     = openstack_containerinfra_cluster_v1.zephyr_test1.kubeconfig.client_certificate
    client_key             = openstack_containerinfra_cluster_v1.zephyr_test1.kubeconfig.client_key
  }
}

# kubernetes-1.23-zephyr-test1 Magnum Kubernetes Cluster Template
resource "openstack_containerinfra_clustertemplate_v1" "kubernetes_1_23_zephyr_test1" {
  name                  = "kubernetes-1.23-zephyr-test1"
  image                 = "fedora-coreos-35.20220116.3.0-x86_64"
  coe                   = "kubernetes"
  server_type           = "vm"
  master_flavor         = "m1.2xlarge"
  flavor                = "m1.4xlarge"
  volume_driver         = "cinder"
  docker_storage_driver = "overlay2"
  docker_volume_size    = 100
  network_driver        = "flannel"
  floating_ip_enabled   = true
  master_lb_enabled     = false
  external_network_id   = "28cf8e6a-bb4f-4ff2-8c1b-f018fd4e792f"
  dns_nameserver        = "100.64.1.1"

  labels = {
    container_infra_prefix           = "registry.centrinix.cloud/openstack/"
    node_problem_detector_tag        = "v0.8.15"
    selinux_mode                     = "permissive"
    boot_volume_size                 = "20"
    boot_volume_type                 = "fc_r1"
    docker_volume_type               = "fc_r1"
  }
}

# zephyr-test1 Magnum Kubernetes Cluster
resource "openstack_containerinfra_cluster_v1" "zephyr_test1" {
  name                = "zephyr-test1"
  cluster_template_id = openstack_containerinfra_clustertemplate_v1.kubernetes_1_23_zephyr_test1.id
  floating_ip_enabled = true
  master_count        = 1
  node_count          = 1
  keypair             = "test2"
  merge_labels        = true

  labels = {
    availability_zone    = "az1"
    auto_scaling_enabled = "False"
    auto_healing_enabled = "False"
  }

  depends_on          = [openstack_containerinfra_clustertemplate_v1.kubernetes_1_23_zephyr_test1]
}

# az3-linux-arm64 Node Group
resource "openstack_containerinfra_nodegroup_v1" "az3_linux_arm64" {
  name                = "az3-linux-arm64"
  cluster_id          = openstack_containerinfra_cluster_v1.zephyr_test1.id
  image_id            = "fedora-coreos-35.20220116.3.0-aarch64"
  flavor_id           = "m1a.4xlarge"
  docker_volume_size  = 100
  role                = "worker"
  node_count          = 1
  merge_labels        = true

  labels = {
    availability_zone = "az3"
  }

  depends_on          = [openstack_containerinfra_cluster_v1.zephyr_test1]
}

# az3-linux-x64 Node Group
resource "openstack_containerinfra_nodegroup_v1" "az3_linux_x64" {
  name                = "az3-linux-x64"
  cluster_id          = openstack_containerinfra_cluster_v1.zephyr_test1.id
  image_id            = "fedora-coreos-35.20220116.3.0-x86_64"
  flavor_id           = "m1.4xlarge"
  docker_volume_size  = 100
  role                = "worker"
  node_count          = 1
  merge_labels        = true

  labels = {
    availability_zone = "az3"
  }

  depends_on          = [openstack_containerinfra_cluster_v1.zephyr_test1]
}

# cnx-privileged Pod Security Policy
data "kubectl_path_documents" "cnx_privileged_manifests" {
  pattern = "../../kubernetes/zephyr-runner-v2/cnx/cnx-privileged/privileged-podsecuritypolicy.yaml"
}

resource "kubectl_manifest" "cnx_privileged_manifest" {
  count      = length(data.kubectl_path_documents.cnx_privileged_manifests.documents)
  yaml_body  = element(data.kubectl_path_documents.cnx_privileged_manifests.documents, count.index)
  wait       = true
  depends_on = [openstack_containerinfra_cluster_v1.zephyr_test1]
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
  depends_on = [kubectl_manifest.cnx_privileged_manifest]
}
