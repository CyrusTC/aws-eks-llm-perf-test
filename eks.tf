module "llm_eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.llm_cluster_name
  kubernetes_version = var.llm_cluster_version

  endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.llm_vpc.vpc_id
  subnet_ids = module.llm_vpc.private_subnets

  tags = merge(var.tags, {
    Type = "LLM-Infrastructure"
  })
} 