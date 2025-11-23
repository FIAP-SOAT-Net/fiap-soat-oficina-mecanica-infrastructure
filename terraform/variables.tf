# AWS Region
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

# Environment
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "smart-workshop"
}

# Networking
variable "vpc_id" {
  description = "VPC ID (from RDS infrastructure)"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS (at least 2 in different AZs)"
  type        = list(string)
}

# EKS Configuration
variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.small"]  # Free Tier eligible: 750h/mês
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 1  # FREE TIER: 1 node 24/7 = 750h/mês
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1  # Mínimo para Free Tier
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 2  # Máximo 2 nodes para controle de custos
}

variable "node_disk_size" {
  description = "Disk size for nodes (GB)"
  type        = number
  default     = 20
}

# Database Configuration (RDS)
variable "rds_endpoint" {
  description = "RDS endpoint (from database infrastructure)"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "smart_workshop"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# Application Configuration
variable "api_image" {
  description = "Docker image for API"
  type        = string
  default     = "ghcr.io/fiap-soat-net/fiap-soat-oficina-mecanica:latest"
}

variable "api_replicas" {
  description = "Number of API replicas"
  type        = number
  default     = 1  # FREE TIER: Iniciar com 1 replica
}

variable "api_cpu_request" {
  description = "CPU request for API pods"
  type        = string
  default     = "250m"
}

variable "api_memory_request" {
  description = "Memory request for API pods"
  type        = string
  default     = "512Mi"
}

variable "api_cpu_limit" {
  description = "CPU limit for API pods"
  type        = string
  default     = "500m"
}

variable "api_memory_limit" {
  description = "Memory limit for API pods"
  type        = string
  default     = "1Gi"
}

variable "jwt_secret_key" {
  description = "JWT secret key for authentication"
  type        = string
  sensitive   = true
  default     = "your-super-secret-key-must-be-at-least-32-characters-long-change-me"
}

# HPA Configuration
variable "hpa_min_replicas" {
  description = "Minimum replicas for HPA"
  type        = number
  default     = 1  # FREE TIER: Mínimo 1 replica
}

variable "hpa_max_replicas" {
  description = "Maximum replicas for HPA"
  type        = number
  default     = 2  # FREE TIER: Máximo 2 replicas
}

variable "hpa_target_cpu" {
  description = "Target CPU utilization for HPA (%)"
  type        = number
  default     = 70
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "smart-workshop"
    ManagedBy   = "terraform"
  }
}
