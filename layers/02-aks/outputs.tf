output "aks_cluster_name" {
  description = "The name of the AKS Cluster"
  value       = module.aks.cluster_name
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for Azure Workload Identity federation"
  value       = module.aks.oidc_issuer_url
}