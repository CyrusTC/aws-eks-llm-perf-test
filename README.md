# AWS EKS LLM Performance Test

Infrastructure for deploying and testing LLM performance on AWS EKS with GPU nodes.

## Architecture

- **VPC**: 3 AZs with public/private subnets
- **EKS Cluster**: Kubernetes 1.33 with Karpenter for GPU node provisioning
- **GPU Nodes**: G5 instances with NVIDIA A10G GPUs
- **LLM Model**: GPT-OSS-20b served via vLLM

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

3. **Run performance tests by concurrency**:

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
| ----------- | ------- | ------------ | ------------- | ----------------- |
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

### Automated Performance Testing Script

For testing across multiple concurrency levels, use this automated script:

```bash
#!/bin/bash

# Configuration
CONCURRENCY_LEVELS=(10 20 40 80 120 200)
INSTANCE_SIZE="G5.8xlarge"
TP=4
PP=0
SHM="10Gi"
INPUT_TOKEN_SIZE=200
NUM_PROMPTS=100
MODEL_NAME="openai/gpt-oss-20b"
SERVICE_URL="http://llm-gpu.llm.svc.cluster.local:8000"

echo "=== Automated Performance Testing ==="
echo "Instance Size: $INSTANCE_SIZE"
echo "Tensor Parallel Size: $TP"
echo "Pipeline Parallel Size: $PP"
echo "SHM Memory Size: $SHM"
echo "Model: $MODEL_NAME"
echo "Input Token Size: $INPUT_TOKEN_SIZE"
echo "Number of Prompts: $NUM_PROMPTS"
echo "Concurrency Levels: ${CONCURRENCY_LEVELS[@]}"
echo "Started at: $(date)"
echo "======================================="

# Loop through concurrency levels
for concurrency in "${CONCURRENCY_LEVELS[@]}"; do
    echo ""
    echo "🚀 Starting test: Concurrency $concurrency on $INSTANCE_SIZE"
    echo "⏰ Test started at: $(date)"

    # Calculate prompts based on concurrency for load distribution
    test_prompts=$((NUM_PROMPTS * concurrency / 10))

    echo "📊 Test parameters:"
    echo "   - Concurrency: $concurrency"
    echo "   - Prompts: $test_prompts"
    echo "   - Input tokens: $INPUT_TOKEN_SIZE ± 20"
    echo "   - Output tokens: 100 ± 10"

    # Run genai-perf test
    genai-perf profile -m $MODEL_NAME \
        --url $SERVICE_URL \
        --service-kind openai \
        --endpoint-type completions \
        --num-prompts $test_prompts \
        --synthetic-input-tokens-mean $INPUT_TOKEN_SIZE \
        --synthetic-input-tokens-stddev 20 \
        --output-tokens-mean 100 \
        --output-tokens-stddev 10 \
        --concurrency $concurrency \
        --tokenizer hf-internal-testing/llama-tokenizer \
        --generate-plots

    echo "✅ Completed test: Concurrency $concurrency"
    echo "⏰ Test completed at: $(date)"
    echo "---"

    # Optional: Add delay between tests to allow system to stabilize
    sleep 30
done

echo ""
echo "🎉 All performance tests completed!"
echo "⏰ Full test suite finished at: $(date)"
echo "📁 Results saved in artifacts/ directory"
```

**Usage:**

1. Access the Triton container: `kubectl exec -it deployment/triton-perf -n llm -- bash`
2. Create the script: `nano perf_test_suite.sh`
3. Copy the script content above
4. Make executable: `chmod +x perf_test_suite.sh`
5. Run: `./perf_test_suite.sh`

**Script Features:**

- **Configurable parameters** at the top for easy modification
- **Automatic prompt scaling** based on concurrency level
- **Detailed logging** with timestamps and test parameters
- **Progress tracking** through the test suite
- **Stabilization delays** between tests
- **Results organization** in artifacts directory

## Performance Results

### Multi-Instance Performance Analysis

Performance testing across G5 instance types with GPT-OSS-20b model (200±20 input tokens, 100±10 output tokens).

### Instance Specifications

| Instance Type | GPUs    | GPU Memory | vCPUs | RAM   | Tensor Parallel | On-Demand Price (US East)\* |
| ------------- | ------- | ---------- | ----- | ----- | --------------- | --------------------------- |
| G5.8xlarge    | 1x A10G | 24GB       | 32    | 128GB | TP=0            | $2.448/hour                 |
| G5.12xlarge   | 4x A10G | 96GB       | 48    | 192GB | TP=4            | $5.672/hour                 |
| G5.16xlarge   | 1x A10G | 24GB       | 64    | 256GB | TP=0            | $4.352/hour                 |
| G5.48xlarge   | 8x A10G | 192GB      | 192   | 768GB | TP=4            | $16.288/hour                |

\*AWS on-demand pricing as of August 2025

### Performance Summary by Instance Type

#### G5.8xlarge (Single A10G - 24GB VRAM)

| Concurrency | Req/sec | Tokens/sec | Avg Latency | P99 Latency |
| ----------- | ------- | ---------- | ----------- | ----------- |
| 10          | 1.78    | 231        | 5.31s       | 11.48s      |
| 20          | 3.51    | 448        | 5.23s       | 7.39s       |
| 40          | 5.61    | 706        | 6.28s       | 10.87s      |
| 80          | 7.02    | 881        | 8.85s       | 16.47s      |
| 120         | 7.88    | 961        | 9.26s       | 19.94s      |
| 200         | 6.31    | 789        | 16.83s      | 33.71s      |

#### G5.12xlarge (4x A10G - 96GB VRAM, TP=4)

| Concurrency | Req/sec | Tokens/sec | Avg Latency | P99 Latency |
| ----------- | ------- | ---------- | ----------- | ----------- |
| 10          | 4.40    | 570        | 2.24s       | 9.49s       |
| 20          | 9.25    | 1,193      | 2.12s       | 2.82s       |
| 40          | 11.28   | 1,428      | 3.39s       | 4.95s       |
| 80          | 12.80   | 1,609      | 5.50s       | 10.74s      |
| 120         | 15.14   | 1,910      | 6.37s       | 13.21s      |
| 200         | 14.81   | 1,891      | 8.97s       | 17.92s      |

#### G5.16xlarge (Single A10G - 24GB VRAM)

| Concurrency | Req/sec | Tokens/sec | Avg Latency | P99 Latency |
| ----------- | ------- | ---------- | ----------- | ----------- |
| 10          | 1.75    | 221        | 5.54s       | 11.43s      |
| 20          | 3.65    | 453        | 5.06s       | 7.61s       |
| 40          | 5.65    | 706        | 6.16s       | 10.72s      |
| 80          | 7.07    | 896        | 8.67s       | 15.36s      |
| 120         | 8.07    | 985        | 9.20s       | 20.33s      |
| 200         | 7.26    | 892        | 11.96s      | 25.82s      |

#### G5.48xlarge (8x A10G - 192GB VRAM, TP=4)

| Concurrency | Req/sec | Tokens/sec | Avg Latency | P99 Latency |
| ----------- | ------- | ---------- | ----------- | ----------- |
| 10          | 6.14    | 781        | 1.61s       | 1.89s       |
| 20          | 8.33    | 1,073      | 2.32s       | 2.83s       |
| 40          | 10.41   | 1,307      | 3.64s       | 4.41s       |
| 80          | 11.25   | 1,401      | 6.48s       | 7.87s       |
| 120         | 10.46   | 1,364      | 9.54s       | 12.06s      |
| 200         | 9.08    | 1,149      | 16.97s      | 23.41s      |

### Price-to-Performance Analysis

#### Peak Throughput Comparison (tokens/sec per dollar/hour)

| Instance Type | Peak Tokens/sec | Cost/Hour | Tokens per $/Hour | Multi-Instance Alternative                     |
| ------------- | --------------- | --------- | ----------------- | ---------------------------------------------- |
| G5.8xlarge    | 961 (C120)      | $2.448    | 392.6             | 6x instances = 5,766 tokens/sec @ $14.69/hour  |
| G5.12xlarge   | 1,910 (C120)    | $5.672    | 336.8             | Single-instance value                          |
| G5.16xlarge   | 985 (C120)      | $4.352    | 226.3             | 4x instances = 3,940 tokens/sec @ $17.41/hour  |
| G5.48xlarge   | 1,401 (C80)     | $16.288   | 86.0              | 7x G5.8xlarge = 6,727 tokens/sec @ $17.14/hour |

#### Low Latency Comparison (< 3s average latency)

| Instance Type | Latency Config | Tokens/sec | Cost/Hour | Tokens per $/Hour |
| ------------- | -------------- | ---------- | --------- | ----------------- |
| G5.8xlarge    | 5.23s @ C20    | 448        | $2.448    | 183.0             |
| G5.12xlarge   | 2.12s @ C20    | 1,193      | $5.672    | 210.4             |
| G5.16xlarge   | 5.06s @ C20    | 453        | $4.352    | 104.1             |
| G5.48xlarge   | 1.61s @ C10    | 781        | $16.288   | 47.9              |

### Key Performance Insights

#### Scaling Efficiency

- **Tensor Parallelism Impact**: TP=4 configurations show 2-3x latency improvement over single GPU
- **Single GPU Plateau**: G5.8xlarge and G5.16xlarge peak around 8-10 req/sec
- **Multi-GPU Scaling**: G5.12xlarge achieves highest absolute throughput (1,910 tokens/sec)

#### Cost Optimization Strategies

**For Maximum Throughput**:

- **Cost-Effective**: 6x G5.8xlarge instances = 5,766 tokens/sec @ $14.69/hour (392.6 tokens per $/hour)
- **Operational Simplicity**: 1x G5.12xlarge = 1,910 tokens/sec @ $5.67/hour (336.8 tokens per $/hour)

**For Low Latency**:

- **Value**: G5.12xlarge @ C20 = 2.12s latency, 210.4 tokens per $/hour
- **Ultra-Low Latency**: G5.48xlarge @ C10 = 1.61s latency, 47.9 tokens per $/hour (3.4x more expensive)

**Multi-Instance vs Single Large Instance**:

- 7x G5.8xlarge delivers 4.8x more throughput than 1x G5.48xlarge at similar cost
- G5.48xlarge only justified for ultra-low latency requirements (< 2s)
- G5.12xlarge offers balance of performance, cost, and operational simplicity

## Monitoring

```bash
# Check pod status
kubectl get pods -n llm

# View logs
kubectl logs -n llm -l app=llm --tail=50

# Check GPU nodes
kubectl get nodes -l instanceType=gpu
```
