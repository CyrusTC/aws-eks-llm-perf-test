# LLM VPC Variables
variable "llm_vpc_name" {
  description = "Name of the VPC for LLM EKS cluster"
  type        = string
  default     = "llm-vpc"
}

variable "llm_vpc_cidr" {
  description = "CIDR block for LLM VPC"
  type        = string
  default     = "11.0.0.0/16"
}

variable "llm_vpc_region" {
  description = "AWS region for LLM VPC deployment"
  type        = string
  default     = "us-east-1"
}

variable "llm_vpc_azs" {
  description = "Availability zones for LLM VPC"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# LLM EKS Variables
variable "llm_cluster_version" {
  description = "Kubernetes version for LLM EKS cluster"
  type        = string
  default     = "1.33"
}

variable "llm_cluster_name" {
  description = "Name of the LLM EKS cluster"
  type        = string
  default     = "llm-eks-cluster"
}

variable "llm_model" {
  description = "LLM model to be deployed"
  type        = string
  default     = "openai/gpt-oss-20b"
}

# EKS Admin Access Variables
variable "enable_additional_admin" {
  description = "Whether to provision additional EKS admin access"
  type        = bool
  default     = false
}

variable "admin_principal_arn" {
  description = "ARN of the principal (role/user) to be granted EKS admin access"
  type        = string
  default     = null
}

# Common tags for all resources
variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "deepseek-eks-openwebui"
    Terraform   = "true"
  }
}
