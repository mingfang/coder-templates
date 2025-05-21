data "coder_parameter" "langflow" {
  name         = "langflow"
  display_name = "LangFlow"
  type         = "bool"
  default      = false
  mutable      = true
  order        = index(local.app_order, "langflow")
}

resource "coder_app" "langflow" {
  count        = data.coder_parameter.langflow.value ? data.coder_workspace.me.start_count : 0
  agent_id     = coder_agent.pod.id
  slug         = "langflow"
  display_name = "LangFlow"
  url          = "http://localhost:7860"
  icon         = "https://framerusercontent.com/images/nOfdJGAX6qhOog6bqsyOeqehA.svg"
  subdomain    = true
  share        = "owner"
  order        = index(local.app_order, "langflow")

  healthcheck {
    url       = "http://localhost:7860/index.html"
    interval  = 3
    threshold = 10
  }
}

resource "coder_script" "langflow" {
  count        = data.coder_parameter.langflow.value ? data.coder_workspace.me.start_count : 0
  agent_id     = coder_agent.pod.id
  display_name = "langflow"
  run_on_start = true
  script       = <<-EOF
  socat TCP4-LISTEN:7860,reuseaddr,fork,ignoreeof TCP4:langflow:7860 > /dev/null 2>&1 &
  EOF

}

resource "kubernetes_service" "langflow" {
  count = data.coder_parameter.langflow.value ? data.coder_workspace.me.start_count : 0
  metadata {
    name      = "langflow"
    namespace = kubernetes_namespace.this.metadata.0.name
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "langflow"
    }
    port {
      port = 7860
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "langflow" {
  count = data.coder_parameter.langflow.value ? data.coder_workspace.me.start_count : 0
  metadata {
    name      = "langflow"
    namespace = kubernetes_namespace.this.metadata.0.name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "langflow"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "langflow"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.this.metadata[0].name
        security_context {
          run_as_user = 1000
          fs_group    = 1000
        }

        container {
          name              = "langflow"
          image             = "langflowai/langflow:latest"
          image_pull_policy = "Always"

          env {
            name  = "LANGFLOW_PORT"
            value = "7860"
          }
          env {
            name  = "LANGFLOW_DATABASE_URL"
            value = "sqlite:////data/langflow/langflow.db"
          }
          env {
            name  = "LANGFLOW_COMPONENTS_PATH"
            value = "/data/langflow/components/"
          }
          env {
            name  = "LANGFLOW_CONFIG_DIR"
            value = "/data/langflow/config/"
          }
          env {
            name  = "LANGFLOW_SECRET_KEY"
            value = "d4RKaUjc8Jjd7hYMWVdW2WDqqMp0l7sEabA-JMMZjtI"
          }

          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "512Mi"
            }
          }

          security_context {
            run_as_user = "1000"
          }

          volume_mount {
            name       = "home"
            mount_path = "/data"
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
          }
        }
      }
    }
  }

  wait_for_rollout = false
}