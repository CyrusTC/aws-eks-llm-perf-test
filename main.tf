terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.8"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }
  }
}

# Default provider configuration
provider "aws" {
  region = var.llm_vpc_region

  default_tags {
    tags = var.tags
  }
}
# LLM EKS Helm Provider
provider "helm" {
  kubernetes {
    host                   = module.llm_eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.llm_eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "/usr/local/bin/aws"
      args        = ["eks", "get-token", "--cluster-name", module.llm_eks.cluster_name, "--region", var.llm_vpc_region]
    }
  }
}

# LLM EKS Kubectl Provider
provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.llm_eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.llm_eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "/usr/local/bin/aws"
    args        = ["eks", "get-token", "--cluster-name", module.llm_eks.cluster_name, "--region", var.llm_vpc_region]
  }
}