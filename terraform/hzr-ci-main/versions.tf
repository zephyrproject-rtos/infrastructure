terraform {
  required_version = ">= 0.14.0"

  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.82.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.4.1"
    }
  }
}
