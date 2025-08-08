# LLM Namespace
resource "kubectl_manifest" "llm_namespace" {

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "llm"
    }
  })

  depends_on = [module.llm_eks]
}

# GPU LLM Deployment
resource "kubectl_manifest" "llm_gpu_deployment" {

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "llm-gpu"
      namespace = "llm"
      labels = {
        app = "llm"
      }
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          app = "llm"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "llm"
          }
        }
        spec = {
          nodeSelector = {
            owner        = "llm-team"
            instanceType = "gpu"
          }
          tolerations = [
            {
              key      = "nvidia.com/gpu"
              operator = "Exists"
              effect   = "NoSchedule"
            }
          ]
          containers = [
            {
              name  = "llm"
              image = "vllm/vllm-openai:latest"
              command = [
                "bash",
                "-c",
                <<-EOT
                uv venv --python 3.12 --seed && \
                source .venv/bin/activate && \
                uv pip install --pre vllm \
                  --extra-index-url https://wheels.vllm.ai/gpt-oss/ \
                  --extra-index-url https://download.pytorch.org/whl/nightly/cu128 \
                  --index-strategy unsafe-best-match && \
                VLLM_ATTENTION_BACKEND=TRITON_ATTN_VLLM_V1 vllm serve ${var.llm_model} --max_model 100000
                EOT
              ]
              ports = [
                {
                  containerPort = 8000
                  protocol      = "TCP"
                }
              ]
              resources = {
                limits = {
                  cpu              = "32"
                  memory           = "100Gi"
                  "nvidia.com/gpu" = "1"
                }
                requests = {
                  cpu              = "16"
                  memory           = "30Gi"
                  "nvidia.com/gpu" = "1"
                }
              }
              livenessProbe = {
                httpGet = {
                  path = "/health"
                  port = 8000
                }
                initialDelaySeconds = 300
                periodSeconds       = 10
              }
              readinessProbe = {
                httpGet = {
                  path = "/health"
                  port = 8000
                }
                initialDelaySeconds = 300
                periodSeconds       = 5
              }
            }
          ]
        }
      }
    }
  })

  depends_on = [
    kubectl_manifest.llm_namespace,
    kubectl_manifest.llm_gpu_nodepool
  ]
}

# LLM Service
resource "kubectl_manifest" "llm_service" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "llm-gpu"
      namespace = "llm"
    }
    spec = {
      selector = {
        app = "llm"
      }
      ports = [
        {
          port       = 8000
          targetPort = 8000
          protocol   = "TCP"
        }
      ]
    }
  })

  depends_on = [kubectl_manifest.llm_namespace]
}