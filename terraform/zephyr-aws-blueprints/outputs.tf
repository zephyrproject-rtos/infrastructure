output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = module.eks_blueprints.configure_kubectl
}

output "eks_cluster_endpoint" {
  description = "Elastic Kubernetes Service Cluster Endpoint"
  value       = module.eks_blueprints.eks_cluster_endpoint
}

output "eks_cluster_ca_certificate" {
  description = "Elastic Kubernetes Service Cluster CA Certificate"
  value       = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
}

output "eks_cluster_auth_token" {
  description = "Elastic Kubernetes Service Authentication Token"
  value       = data.aws_eks_cluster_auth.this.token
}
