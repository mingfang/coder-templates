
locals {
  name = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
  labels = {
    "app.kubernetes.io/managed-by" = "coder"
  }
}

resource "kubernetes_namespace" "this" {
  metadata {
    name   = local.name
    labels = local.labels
  }
}

resource "kubernetes_service_account" "this" {
  metadata {
    name      = local.name
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }
}

resource "kubernetes_role_binding" "this" {
  metadata {
    name      = local.name
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.this.metadata[0].name
    namespace = kubernetes_namespace.this.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding" "this" {
  metadata {
    name   = local.name
    labels = local.labels
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.this.metadata[0].name
    namespace = kubernetes_namespace.this.metadata[0].name
  }
}

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-home"
    namespace = kubernetes_namespace.this.metadata.0.name
    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
      "app.kubernetes.io/part-of"  = "coder"
      //Coder-specific labels.
      "com.coder.resource"       = "true"
      "com.coder.workspace.id"   = data.coder_workspace.me.id
      "com.coder.workspace.name" = data.coder_workspace.me.name
      "com.coder.user.id"        = data.coder_workspace_owner.me.id
      "com.coder.user.username"  = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "${data.coder_parameter.home_disk_size.value}Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "workspace" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim.home
  ]
  wait_for_rollout = false
  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
    namespace = kubernetes_namespace.this.metadata.0.name
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "coder-workspace"
      }
    }
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "coder-workspace"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.this.metadata[0].name
        security_context {
          run_as_user = 1000
          fs_group    = 1000
        }

        # workspace
        container {
          name              = "workspace"
          image             = data.coder_parameter.workspace_image.value
          image_pull_policy = "Always"
          command           = ["sh", "-c", replace(coder_agent.pod.init_script, data.coder_workspace.me.access_url, var.coder_access_url)]

          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.pod.token
          }
          env {
            name  = "DOCKER_HOST"
            value = "tcp://localhost:2375"
          }
          env {
            name = "NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "512Mi"
            }
            limits = {
              "cpu"    = data.coder_parameter.cpu.value
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }
          }

          security_context {
            privileged  = true
            run_as_user = "1000"
          }

          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }
          volume_mount {
            name       = "scratch"
            mount_path = "/scratch"
          }
        }

        # dind
        container {
          name  = "dind"
          image = "docker:dind"
          args  = ["--insecure-registry=0.0.0.0/0"]
          env {
            name  = "DOCKER_TLS_CERTDIR"
            value = ""
          }

          security_context {
            privileged  = true
            run_as_user = 0
          }

          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }
        }

        # pgadmin
        dynamic "container" {
          for_each = data.coder_parameter.pgadmin.value ? { "test" = "test" } : {}
          content {
            name  = "pgadmin"
            image = "docker.io/dpage/pgadmin4:latest"
            security_context {
              run_as_user = "5050"
            }
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
        }

        # filebrowser
        dynamic "container" {
          for_each = data.coder_parameter.filebrowser.value ? { "test" = "test" } : {}
          content {
            name  = "filebrowser"
            image = "filebrowser/filebrowser:latest"
            args  = ["--noauth", "--root", "/home/coder", "--port", "13339", "-d", "/home/coder/.filebrowser.db"]

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
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
            read_only  = false
          }
        }
        volume {
          name = "scratch"
          empty_dir {
            size_limit = "1Gi"
          }
        }
      }
    }
  }
}