data "coder_parameter" "filebrowser" {
  name         = "filebrowser"
  display_name = "Files"
  type         = "bool"
  default      = true
  mutable      = true
  order        = index(local.app_order, "filebrowser")
}

resource "coder_app" "filebrowser" {
  count        = data.coder_parameter.filebrowser.value ? data.coder_workspace.me.start_count : 0
  agent_id     = coder_agent.pod.id
  slug         = "files"
  display_name = "Files"
  icon         = "https://raw.githubusercontent.com/matifali/logos/main/database.svg"
  url          = "http://localhost:13339"
  subdomain    = true
  share        = "owner"
  order        = index(local.app_order, "filebrowser")

  healthcheck {
    url       = "http://localhost:13339/healthz"
    interval  = 3
    threshold = 10
  }
}

resource "coder_script" "filebrowser" {
  count        = data.coder_parameter.filebrowser.value ? data.coder_workspace.me.start_count : 0
  agent_id     = coder_agent.pod.id
  display_name = "filebrowser"
  run_on_start = true
  script       = <<-EOF
  socat TCP4-LISTEN:13339,reuseaddr,fork,ignoreeof TCP4:filebrowser:13339 > /dev/null 2>&1 &
  EOF

}

resource "kubernetes_service" "filebrowser" {
  count = data.coder_parameter.filebrowser.value ? data.coder_workspace.me.start_count : 0
  metadata {
    name      = "filebrowser"
    namespace = kubernetes_namespace.this.metadata.0.name
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "filebrowser"
    }
    port {
      port = 13339
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "filebrowser" {
  count = data.coder_parameter.filebrowser.value ? data.coder_workspace.me.start_count : 0
  metadata {
    name      = "filebrowser"
    namespace = kubernetes_namespace.this.metadata.0.name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "filebrowser"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "filebrowser"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.this.metadata[0].name
        security_context {
          run_as_user = 1000
          fs_group    = 1000
        }

        container {
          name              = "filebrowser"
          image             = "filebrowser/filebrowser:latest"
          image_pull_policy = "Always"

          args = ["--noauth", "--root", "/home/coder", "--port", "13339", "-d", "/home/coder/.filebrowser.db"]

          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "64Mi"
            }
          }

          security_context {
            run_as_user = "1000"
          }

          volume_mount {
            name       = "home"
            mount_path = "/home/coder"
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