# Triton performance testing container
resource "kubectl_manifest" "triton_perf_deployment" {
  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "triton-perf"
      namespace = "llm"
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          app = "triton-perf"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "triton-perf"
          }
        }
        spec = {
          containers = [
            {
              name    = "triton"
              image   = "nvcr.io/nvidia/tritonserver:24.12-py3-sdk"
              command = ["sleep", "infinity"]
              resources = {
                limits = {
                  cpu    = "4"
                  memory = "8Gi"
                }
                requests = {
                  cpu    = "2"
                  memory = "4Gi"
                }
              }
            }
          ]
        }
      }
    }
  })

  depends_on = [kubectl_manifest.llm_namespace]
}
