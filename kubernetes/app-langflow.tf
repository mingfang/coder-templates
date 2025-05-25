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
  icon         = "https://framerusercontent.com/images/nOfdJGAX6qhOog6bqsyOeqehA.svg"
  url          = "https://langflow-${kubernetes_namespace.this.metadata.0.name}.rebelsoft.com"
  external     = true
  order        = index(local.app_order, "langflow")
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
      name = "http"
      port = 7860
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_stateful_set" "langflow" {
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
    service_name = "langflow"
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

resource "kubernetes_ingress_v1" "langflow" {
  count = data.coder_parameter.langflow.value ? data.coder_workspace.me.start_count : 0
  metadata {
    annotations = {
      "nginx.ingress.kubernetes.io/server-alias"       = "langflow-${kubernetes_namespace.this.metadata.0.name}.*"
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
      "nginx.ingress.kubernetes.io/proxy-body-size"    = "10240m"
    }
    name      = "langflow-${kubernetes_namespace.this.metadata.0.name}"
    namespace = kubernetes_namespace.this.metadata.0.name
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "langflow-${kubernetes_namespace.this.metadata.0.name}"
      http {
        path {
          path      = "/"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = kubernetes_service.langflow.0.metadata.0.name
              port {
                number = kubernetes_service.langflow.0.spec.0.port.0.port
              }
            }
          }
        }
      }
    }
  }
}