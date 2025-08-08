# Terraform-Only Infrastructure Policy

## Mandatory Requirements

### 🚫 PROHIBITED

- **NO BASH SCRIPTS**: Absolutely no bash scripts (.sh files) are allowed in this project
- **NO SHELL COMMANDS**: No shell command execution within Terraform (local-exec, remote-exec)
- **NO EXTERNAL SCRIPTS**: No external script dependencies or calls

### ✅ REQUIRED

- **TERRAFORM ONLY**: All infrastructure must be defined in Terraform (.tf files)
- **DECLARATIVE APPROACH**: Use Terraform resources, data sources, and providers exclusively
- **NATIVE RESOURCES**: Leverage native Terraform resources and providers (aws, kubernetes, kubectl, helm)

## Implementation Guidelines

### Infrastructure Provisioning

- Use Terraform modules and resources for all AWS infrastructure
- Use Kubernetes/kubectl providers for Kubernetes resources
- Use Helm provider for Helm chart deployments

### Configuration Management

- Use Terraform templatefile() function for configuration templates
- Use Kubernetes ConfigMaps and Secrets for application configuration
- Use Terraform variables and locals for parameterization

### Deployment Automation

- Use `terraform init`, `terraform plan`, `terraform apply` commands directly
- Use Terraform depends_on for resource ordering
- Use Terraform lifecycle rules for resource management

## Rationale

1. **Consistency**: Pure Terraform ensures consistent, reproducible infrastructure
2. **Maintainability**: Single tool reduces complexity and maintenance overhead
3. **State Management**: Terraform state tracking works optimally with native resources
4. **Security**: Eliminates shell injection risks and script-based vulnerabilities
5. **Portability**: Terraform code is platform-agnostic and cloud-portable

## Enforcement

Any pull request or code change that introduces bash scripts or shell commands will be rejected. All automation must be achieved through Terraform's native capabilities.
