module "llm_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.llm_vpc_name
  cidr = var.llm_vpc_cidr

  azs             = var.llm_vpc_azs
  private_subnets = [for i, az in var.llm_vpc_azs : cidrsubnet(var.llm_vpc_cidr, 4, i)]
  public_subnets  = [for i, az in var.llm_vpc_azs : cidrsubnet(var.llm_vpc_cidr, 4, i + 3)]

  enable_nat_gateway = true
  single_nat_gateway = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Disable VPC Flow Logs
  enable_flow_log = false

  tags = merge(var.tags, {
    Type = "LLM-Infrastructure"
  })

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "kubernetes.io/cluster/${var.llm_cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "kubernetes.io/cluster/${var.llm_cluster_name}" = "shared"
  }
} 