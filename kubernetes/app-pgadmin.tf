data "coder_parameter" "pgadmin" {
  name         = "pgadmin"
  display_name = "PGAdmin"
  type         = "bool"
  default      = false
  mutable      = true
  order        = index(local.app_order, "pgadmin")
}

resource "coder_app" "pgadmin" {
  count        = data.coder_parameter.pgadmin.value ? data.coder_workspace.me.start_count : 0
  agent_id     = coder_agent.pod.id
  slug         = "pgadmin"
  display_name = "pgAdmin"
  icon         = "https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/Postgresql_elephant.svg/1200px-Postgresql_elephant.svg.png"
  url          = "http://localhost:5050"
  subdomain    = true
  share        = "owner"
  order        = index(local.app_order, "pgadmin")

  healthcheck {
    url       = "http://localhost:5050/misc/ping"
    interval  = 3
    threshold = 10
  }
}

resource "coder_script" "pgadmin" {
  count        = data.coder_parameter.pgadmin.value ? data.coder_workspace.me.start_count : 0
  agent_id     = coder_agent.pod.id
  display_name = "pgadmin"
  run_on_start = true
  script       = <<-EOF
  socat TCP4-LISTEN:5050,reuseaddr,fork,ignoreeof TCP4:pgadmin:5050 > /dev/null 2>&1 &
  EOF

}

resource "kubernetes_service" "pgadmin" {
  count = data.coder_parameter.pgadmin.value ? data.coder_workspace.me.start_count : 0
  metadata {
    name      = "pgadmin"
    namespace = kubernetes_namespace.this.metadata.0.name
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "pgadmin"
    }
    port {
      port = 5050
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "pgadmin" {
  count = data.coder_parameter.pgadmin.value ? data.coder_workspace.me.start_count : 0
  metadata {
    name      = "pgadmin"
    namespace = kubernetes_namespace.this.metadata.0.name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "pgadmin"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "pgadmin"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.this.metadata[0].name
        security_context {
          run_as_user = 1000
          fs_group    = 1000
        }

        container {
          name              = "pgadmin"
          image             = "docker.io/dpage/pgadmin4:latest"
          image_pull_policy = "Always"

          env {
            name  = "PGADMIN_DEFAULT_EMAIL"
            value = data.coder_workspace_owner.me.email
          }
          env {
            name  = "PGADMIN_DEFAULT_PASSWORD"
            value = "pgadmin"
          }
          env {
            name  = "PGADMIN_LISTEN_PORT"
            value = "5050"
          }
          env {
            name  = "PGADMIN_DISABLE_POSTFIX"
            value = "True"
          }
          env {
            name  = "PGADMIN_CONFIG_SERVER_MODE"
            value = "False"
          }
          env {
            name  = "PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED"
            value = "False"
          }
          env {
            name  = "PGADMIN_CONFIG_WTF_CSRF_ENABLED"
            value = "False"
          }

          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "256Mi"
            }
          }

          security_context {
            run_as_user = "5050"
          }

          volume_mount {
            name       = "home"
            mount_path = "/home/coder"
          }
          volume_mount {
            name       = "home"
            mount_path = "/var/lib/pgadmin"
            sub_path   = ".pgadmin"
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