# LLM EKS Admin Access
resource "aws_eks_access_entry" "llm_admin" {
  count = var.enable_additional_admin && var.admin_principal_arn != null ? 1 : 0

  cluster_name   = module.llm_eks.cluster_name
  principal_arn  = var.admin_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "llm_admin" {
  count = var.enable_additional_admin && var.admin_principal_arn != null ? 1 : 0

  cluster_name  = module.llm_eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = var.admin_principal_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.llm_admin]
} 