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

## Performance Testing

The infrastructure includes a persistent Triton container for manual performance testing:

### Running Performance Tests

1. **Access the Triton container**:
   ```bash
   kubectl exec -it deployment/triton-perf -n llm -- bash
   ```

2. **Run basic inference test**:
   ```bash
   curl -X POST http://llm-gpu.llm.svc.cluster.local:8000/v1/completions \
     -H "Content-Type: application/json" \
     -d '{
       "model": "openai/gpt-oss-20b",
       "prompt": "The capital of France is",
       "max_tokens": 10,
       "temperature": 0.7
     }'
   ```

3. **Run comprehensive performance tests by concurrency**:

   **Concurrency 20 (Baseline)**:
   ```bash
   genai-perf profile -m openai/gpt-oss-20b \
     --url http://llm-gpu.llm.svc.cluster.local:8000 \
     --service-kind openai \
     --endpoint-type completions \
     --num-prompts 100 \
     --synthetic-input-tokens-mean 200 \
     --synthetic-input-tokens-stddev 20 \
     --output-tokens-mean 100 \
     --output-tokens-stddev 10 \
     --concurrency 20 \
     --tokenizer hf-internal-testing/llama-tokenizer \
     --generate-plots
   ```

   **Concurrency 40 (Medium Load)**:
   ```bash
   genai-perf profile -m openai/gpt-oss-20b \
     --url http://llm-gpu.llm.svc.cluster.local:8000 \
     --service-kind openai \
     --endpoint-type completions \
     --num-prompts 200 \
     --synthetic-input-tokens-mean 200 \
     --synthetic-input-tokens-stddev 20 \
     --output-tokens-mean 100 \
     --output-tokens-stddev 10 \
     --concurrency 40 \
     --tokenizer hf-internal-testing/llama-tokenizer \
     --generate-plots
   ```

   **Concurrency 80 (High Load)**:
   ```bash
   genai-perf profile -m openai/gpt-oss-20b \
     --url http://llm-gpu.llm.svc.cluster.local:8000 \
     --service-kind openai \
     --endpoint-type completions \
     --num-prompts 400 \
     --synthetic-input-tokens-mean 200 \
     --synthetic-input-tokens-stddev 20 \
     --output-tokens-mean 100 \
     --output-tokens-stddev 10 \
     --concurrency 80 \
     --tokenizer hf-internal-testing/llama-tokenizer \
     --generate-plots
   ```

   **Concurrency 120 (Very High Load)**:
   ```bash
   genai-perf profile -m openai/gpt-oss-20b \
     --url http://llm-gpu.llm.svc.cluster.local:8000 \
     --service-kind openai \
     --endpoint-type completions \
     --num-prompts 600 \
     --synthetic-input-tokens-mean 200 \
     --synthetic-input-tokens-stddev 20 \
     --output-tokens-mean 100 \
     --output-tokens-stddev 10 \
     --concurrency 120 \
     --tokenizer hf-internal-testing/llama-tokenizer \
     --generate-plots
   ```

   **Concurrency 200 (Maximum Load)**:
   ```bash
   genai-perf profile -m openai/gpt-oss-20b \
     --url http://llm-gpu.llm.svc.cluster.local:8000 \
     --service-kind openai \
     --endpoint-type completions \
     --num-prompts 1000 \
     --synthetic-input-tokens-mean 200 \
     --synthetic-input-tokens-stddev 20 \
     --output-tokens-mean 100 \
     --output-tokens-stddev 10 \
     --concurrency 200 \
     --tokenizer hf-internal-testing/llama-tokenizer \
     --generate-plots
   ```

### Test Parameters by Concurrency Level
| Concurrency | Prompts | Input Tokens | Output Tokens | Expected Duration |
|-------------|---------|--------------|---------------|-------------------|
| 20          | 100     | 200 ± 20     | 100 ± 10      | ~2-3 minutes      |
| 40          | 200     | 200 ± 20     | 100 ± 10      | ~3-4 minutes      |
| 80          | 400     | 200 ± 20     | 100 ± 10      | ~5-6 minutes      |
| 120         | 600     | 200 ± 20     | 100 ± 10      | ~7-8 minutes      |
| 200         | 1000    | 200 ± 20     | 100 ± 10      | ~10-12 minutes    |

### Key Metrics to Monitor
- **Throughput**: Requests per second
- **Latency**: P50, P95, P99 response times
- **Token throughput**: Input/output tokens per second
- **Error rate**: Failed requests percentage
- **GPU utilization**: Memory and compute usage

The Triton container runs persistently, so you can run multiple tests and compare results across different concurrency levels.

## Performance Results

### Sample Test Results (G5.8xlarge - Concurrency 10)

```
                                   NVIDIA GenAI-Perf | LLM Metrics
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┓
┃                         Statistic ┃      avg ┃    min ┃       max ┃      p99 ┃      p90 ┃      p75 ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━┩
│              Request latency (ms) │ 5,043.38 │ 465.89 │ 10,071.94 │ 9,903.36 │ 8,738.60 │ 4,975.83 │
│            Output sequence length │   124.18 │  12.00 │    285.00 │   193.88 │   143.60 │   134.00 │
│             Input sequence length │   203.31 │ 155.00 │    255.00 │   247.63 │   228.60 │   215.50 │
│ Output token throughput (per sec) │   236.62 │    N/A │       N/A │      N/A │      N/A │      N/A │
│      Request throughput (per sec) │     1.91 │    N/A │       N/A │      N/A │      N/A │      N/A │
└───────────────────────────────────┴──────────┴────────┴───────────┴──────────┴──────────┴──────────┘
```

### Sample Test Results (G5.8xlarge - Concurrency 20)

```
                                    NVIDIA GenAI-Perf | LLM Metrics
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┓
┃                         Statistic ┃      avg ┃      min ┃      max ┃      p99 ┃      p90 ┃      p75 ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━┩
│              Request latency (ms) │ 4,305.56 │ 2,064.23 │ 5,391.71 │ 5,345.23 │ 5,046.14 │ 4,645.27 │
│            Output sequence length │   125.45 │    62.00 │   255.00 │   188.08 │   148.20 │   132.00 │
│             Input sequence length │   202.12 │   151.00 │   255.00 │   248.62 │   231.00 │   212.50 │
│ Output token throughput (per sec) │   554.70 │      N/A │      N/A │      N/A │      N/A │      N/A │
│      Request throughput (per sec) │     4.42 │      N/A │      N/A │      N/A │      N/A │      N/A │
└───────────────────────────────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
```

### Sample Test Results (G5.8xlarge - Concurrency 40)

```
                                   NVIDIA GenAI-Perf | LLM Metrics
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┓
┃                         Statistic ┃      avg ┃    min ┃       max ┃      p99 ┃      p90 ┃      p75 ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━┩
│              Request latency (ms) │ 6,090.43 │ 384.13 │ 10,079.55 │ 9,274.37 │ 8,173.34 │ 7,191.06 │
│            Output sequence length │   125.30 │   2.00 │    396.00 │   190.97 │   144.30 │   133.00 │
│             Input sequence length │   202.69 │ 151.00 │    255.00 │   244.81 │   231.00 │   217.00 │
│ Output token throughput (per sec) │   766.65 │    N/A │       N/A │      N/A │      N/A │      N/A │
│      Request throughput (per sec) │     6.15 │    N/A │       N/A │      N/A │      N/A │      N/A │
└───────────────────────────────────┴──────────┴────────┴───────────┴──────────┴──────────┴──────────┘
```

### Sample Test Results (G5.8xlarge - Concurrency 80)

```
                                      NVIDIA GenAI-Perf | LLM Metrics
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━┓
┃                         Statistic ┃      avg ┃      min ┃       max ┃       p99 ┃       p90 ┃       p75 ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━┩
│              Request latency (ms) │ 9,580.24 │ 4,041.25 │ 21,567.38 │ 20,922.32 │ 17,528.76 │ 12,751.37 │
│            Output sequence length │   126.02 │    75.00 │    596.00 │    221.45 │    144.50 │    132.25 │
│             Input sequence length │   201.64 │   151.00 │    255.00 │    243.65 │    228.50 │    215.25 │
│ Output token throughput (per sec) │   828.76 │      N/A │       N/A │       N/A │       N/A │       N/A │
│      Request throughput (per sec) │     6.58 │      N/A │       N/A │       N/A │       N/A │       N/A │
└───────────────────────────────────┴──────────┴──────────┴───────────┴───────────┴───────────┴───────────┘
```

### Sample Test Results (G5.8xlarge - Concurrency 120)

```
                                      NVIDIA GenAI-Perf | LLM Metrics
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━┓
┃                         Statistic ┃      avg ┃      min ┃       max ┃       p99 ┃       p90 ┃       p75 ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━┩
│              Request latency (ms) │ 9,945.11 │ 5,875.81 │ 22,212.10 │ 19,997.09 │ 15,565.79 │ 11,282.18 │
│            Output sequence length │   129.28 │    79.00 │    638.00 │    319.57 │    149.10 │    131.00 │
│             Input sequence length │   200.88 │   139.00 │    255.00 │    243.21 │    229.00 │    215.00 │
│ Output token throughput (per sec) │ 1,007.91 │      N/A │       N/A │       N/A │       N/A │       N/A │
│      Request throughput (per sec) │     7.80 │      N/A │       N/A │       N/A │       N/A │       N/A │
└───────────────────────────────────┴──────────┴──────────┴───────────┴───────────┴───────────┴───────────┘
```

### Sample Test Results (G5.8xlarge - Concurrency 200)

```
                                      NVIDIA GenAI-Perf | LLM Metrics
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━┓
┃                         Statistic ┃       avg ┃      min ┃       max ┃       p99 ┃       p90 ┃       p75 ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━┩
│              Request latency (ms) │ 17,846.00 │ 5,862.05 │ 30,787.32 │ 30,231.19 │ 22,843.58 │ 18,836.35 │
│            Output sequence length │    125.66 │    26.00 │    436.00 │    244.40 │    144.00 │    133.00 │
│             Input sequence length │    200.98 │   151.00 │    255.00 │    246.40 │    229.00 │    215.00 │
│ Output token throughput (per sec) │    771.25 │      N/A │       N/A │       N/A │       N/A │       N/A │
│      Request throughput (per sec) │      6.14 │      N/A │       N/A │       N/A │       N/A │       N/A │
└───────────────────────────────────┴───────────┴──────────┴───────────┴───────────┴───────────┴───────────┘
```

### Key Performance Insights

**Hardware**: G5.8xlarge (NVIDIA A10G, 24GB VRAM, 32 vCPUs, 128 GiB RAM)

**Complete Performance Scaling Analysis**:

| Concurrency | Req/sec | Tokens/sec | Avg Latency | P99 Latency | Optimal Use Case |
|-------------|---------|------------|-------------|-------------|------------------|
| 10          | 1.91    | 236.62     | 5.04s       | 9.90s       | Development/Testing |
| 20          | 4.42    | 554.70     | 4.31s       | 5.35s       | **Production (Low Latency)** |
| 40          | 6.15    | 766.65     | 6.09s       | 9.27s       | Balanced Workloads |
| 80          | 6.58    | 828.76     | 9.58s       | 20.92s      | Avoid (Poor Efficiency) |
| 120         | 7.80    | 1,007.91   | 9.95s       | 20.00s      | **Maximum Throughput** |
| 200         | 6.14    | 771.25     | 17.85s      | 30.23s      | Over-Saturated |

**Key Findings**:
- **Optimal Latency**: Concurrency 20 (4.31s avg, 5.35s P99)
- **Peak Throughput**: Concurrency 120 (1,008 tokens/sec, 7.8 req/sec)
- **Saturation Point**: Beyond C120, performance degrades significantly
- **Production Sweet Spot**: C20-40 for most real-world applications

**Generated Artifacts**:
- Performance metrics: `profile_export_genai_perf.json`
- CSV data: `profile_export_genai_perf.csv`
- Visualization plots: Time to First Token, Request Latency, Token distributions

### Expected Performance Scaling
As concurrency increases, expect:
- **Higher throughput** (more requests/sec)
- **Increased latency** (longer response times)
- **Resource saturation** at concurrency 120-200
- **Potential timeouts** under maximum load

## Hardware Specifications

- **Instance Type**: G5.8xlarge
- **GPU**: NVIDIA A10G (24GB VRAM)
- **CPU**: 32 vCPUs
- **Memory**: 128 GiB
- **Network**: Up to 25 Gbps

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
