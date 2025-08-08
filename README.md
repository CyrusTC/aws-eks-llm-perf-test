# AWS EKS LLM Performance Test

Infrastructure for deploying and testing LLM performance on AWS EKS with GPU nodes.

## Architecture

- **VPC**: 3 AZs with public/private subnets
- **EKS Cluster**: Kubernetes 1.33 with Karpenter for GPU node provisioning
- **GPU Nodes**: G5.8xlarge instances with NVIDIA A10G GPUs
- **LLM Model**: GPT-OSS-20b served via vLLM

## FlashAttention 3 Compatibility Issue

### Problem
GPT-OSS-20b model requires FlashAttention 3 support, causing this error on A10G GPUs:
```
AssertionError: Sinks are only supported in FlashAttention 3
```

### Solution
Use Triton attention backend instead of FlashAttention by setting the environment variable:
```bash
VLLM_ATTENTION_BACKEND=TRITON_ATTN_VLLM_V1
```

This is implemented in the Terraform deployment configuration:
```hcl
command = [
  "bash", "-c",
  <<-EOT
  uv venv --python 3.12 --seed && \
  source .venv/bin/activate && \
  uv pip install --pre vllm \
    --extra-index-url https://wheels.vllm.ai/gpt-oss/ \
    --extra-index-url https://download.pytorch.org/whl/nightly/cu128 \
    --index-strategy unsafe-best-match && \
  VLLM_ATTENTION_BACKEND=TRITON_ATTN_VLLM_V1 vllm serve openai/gpt-oss-20b --max_model 100000
  EOT
]
```

## Deployment

```bash
terraform init
terraform apply
```

## Monitoring

```bash
# Check pod status
kubectl get pods -n llm

# View logs
kubectl logs -n llm -l app=llm --tail=50

# Check GPU nodes
kubectl get nodes -l instanceType=gpu
```

## Hardware Specifications

- **Instance Type**: G5.8xlarge
- **GPU**: NVIDIA A10G (24GB VRAM)
- **CPU**: 32 vCPUs
- **Memory**: 128 GiB
- **Network**: Up to 25 Gbps
