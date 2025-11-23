# EKS Cluster Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = aws_eks_cluster.main.name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

# Fargate Profile Outputs
output "fargate_profile_app_id" {
  description = "Fargate profile ID for application namespace"
  value       = aws_eks_fargate_profile.app.id
}

output "fargate_profile_kube_system_id" {
  description = "Fargate profile ID for kube-system namespace"
  value       = aws_eks_fargate_profile.kube_system.id
}

# IAM Outputs
output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "fargate_pod_execution_role_arn" {
  description = "IAM role ARN for Fargate pod execution"
  value       = aws_iam_role.fargate_pod_execution_role.arn
}

# Kubectl Config Command
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

# Application Endpoints (to be populated after K8s deployment)
output "api_service_info" {
  description = "Command to get API service external endpoint"
  value       = "kubectl get svc api-service -n ${var.project_name} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "mailhog_service_info" {
  description = "Command to get MailHog service external endpoint"
  value       = "kubectl get svc mailhog-service -n ${var.project_name} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

# Database Connection
output "database_connection_string" {
  description = "Database connection string (without password)"
  value       = "server=${var.rds_endpoint};port=3306;database=${var.db_name};user=${var.db_username}"
  sensitive   = true
}

# Useful Commands
output "useful_commands" {
  description = "Useful kubectl commands"
  value = <<-EOT
    # Configure kubectl
    aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}
    
    # Get Fargate nodes
    kubectl get nodes
    
    # Get all resources
    kubectl get all -n ${var.project_name}
    
    # Get pods (with node info)
    kubectl get pods -n ${var.project_name} -o wide
    
    # Get services
    kubectl get svc -n ${var.project_name}
    
    # View API logs
    kubectl logs -n ${var.project_name} -l app=api -f
    
    # View MailHog logs
    kubectl logs -n ${var.project_name} -l app=mailhog -f
    
    # Scale API deployment
    kubectl scale deployment api-deployment -n ${var.project_name} --replicas=2
    
    # Get HPA status
    kubectl get hpa -n ${var.project_name}
    
    # Get Fargate profiles
    aws eks list-fargate-profiles --cluster-name ${aws_eks_cluster.main.name}
  EOT
}
