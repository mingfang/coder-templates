data "coder_parameter" "openhands" {
  name         = "openhands"
  display_name = "OpenHands"
  type         = "bool"
  default      = false
  mutable      = true
  order        = index(local.app_order, "openhands")
}

resource "coder_app" "openhands" {
  count        = data.coder_parameter.openhands.value ? data.coder_workspace.me.start_count : 0
  agent_id     = coder_agent.pod.id
  slug         = "openhands"
  display_name = "OpenHands"
  icon         = "https://raw.githubusercontent.com/All-Hands-AI/OpenHands/refs/heads/main/frontend/src/icons/hands.svg"
  url          = "https://openhands-${kubernetes_namespace.this.metadata.0.name}.rebelsoft.com"
  external     = true
  order        = index(local.app_order, "openhands")
}

resource "kubernetes_service" "openhands" {
  count = data.coder_parameter.openhands.value ? data.coder_workspace.me.start_count : 0
  metadata {
    name      = "openhands"
    namespace = kubernetes_namespace.this.metadata.0.name
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "openhands"
    }
    port {
      name = "http"
      port = 3000
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_stateful_set" "openhands" {
  count = data.coder_parameter.openhands.value ? data.coder_workspace.me.start_count : 0
  metadata {
    name      = "openhands"
    namespace = kubernetes_namespace.this.metadata.0.name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "openhands"
      }
    }
    service_name = "openhands"
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "openhands"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.this.metadata[0].name
        security_context {
          run_as_user = 0
          fs_group    = 1000
        }

        container {
          name              = "openhands"
          image             = "registry.rebelsoft.com/openhands"
          image_pull_policy = "Always"

          env {
            name  = "SANDBOX_RUNTIME_CONTAINER_IMAGE"
            value = "docker.all-hands.dev/all-hands-ai/runtime:0.39-nikolaik"
          }
          env {
            name  = "SANDBOX_LOCAL_RUNTIME_URL"
            value = "http://localhost"
          }
          env {
            name  = "SANDBOX_USER_ID"
            value = "1000"
          }
          env {
            name  = "SANDBOX_VOLUMES"
            value = "/workspace:/workspace:rw"
          }
          env {
            name  = "WORKSPACE_MOUNT_PATH_IN_SANDBOX"
            value = "/workspace"
          }
          env {
            name  = "LOG_ALL_EVENTS"
            value = "true"
          }
          env {
            name  = "PUBLIC_URL_PATTERN"
            value = "https://{port}-openhands-${kubernetes_namespace.this.metadata.0.name}.rebelsoft.com"
          }
          env {
            name  = "PERMITTED_CORS_ORIGINS"
            value = "*"
          }
          env {
            name  = "DOCKER_HOST"
            value = "unix:///dind/docker.sock"
          }

          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "512Mi"
            }
          }

          volume_mount {
            name       = "home"
            mount_path = "/.openhands-state"
            sub_path   = ".openhands"
          }
          volume_mount {
            name       = "docker-sock"
            mount_path = "/dind"
          }
        }

        # dind
        container {
          name  = "dind"
          image = "docker:dind"

          args = [
            "--insecure-registry=0.0.0.0/0",
            "--group=1000",
            "--log-level=fatal",
          ]

          env {
            name  = "DOCKER_TLS_CERTDIR"
            value = ""
          }
          env {
            name  = "DOCKER_HOST"
            value = "unix:///dind/docker.sock"
          }

          security_context {
            privileged   = true
            run_as_user  = 0
            run_as_group = 1000
          }

          volume_mount {
            name       = "home"
            mount_path = "/workspace"
            sub_path   = ".openhands/workspace"
          }
          volume_mount {
            name       = "docker-sock"
            mount_path = "/dind"
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
          }
        }
        volume {
          name = "docker-sock"
          empty_dir {
            medium = "Memory"
          }
        }
      }
    }
  }

  wait_for_rollout = false
}

resource "kubernetes_ingress_v1" "openhands" {
  count = data.coder_parameter.openhands.value ? data.coder_workspace.me.start_count : 0
  metadata {
    annotations = {
      "nginx.ingress.kubernetes.io/server-alias"       = "openhands-${kubernetes_namespace.this.metadata.0.name}.*"
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
      "nginx.ingress.kubernetes.io/proxy-body-size"    = "10240m"
    }
    name      = "openhands-${kubernetes_namespace.this.metadata.0.name}"
    namespace = kubernetes_namespace.this.metadata.0.name
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "openhands-${kubernetes_namespace.this.metadata.0.name}"
      http {
        path {
          path      = "/"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = kubernetes_service.openhands.0.metadata.0.name
              port {
                number = kubernetes_service.openhands.0.spec.0.port.0.port
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "openhands-proxy" {
  count = data.coder_parameter.openhands.value ? data.coder_workspace.me.start_count : 0
  metadata {
    annotations = {
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
      "nginx.ingress.kubernetes.io/proxy-body-size"    = "10240m"

      "nginx.ingress.kubernetes.io/server-snippet" = <<-EOF
        server_name ~^(?<port>[0-9]+)-openhands-${kubernetes_namespace.this.metadata.0.name}\..*;
        location ~ / {
          resolver kube-dns.kube-system.svc.cluster.local valid=5s;
          set $service ${kubernetes_service.openhands.0.metadata.0.name}-0.${kubernetes_service.openhands.0.metadata.0.name}.${kubernetes_namespace.this.metadata.0.name}.svc.cluster.local;
          proxy_pass http://$service:$port;

          proxy_redirect          off;
          proxy_set_header        Host            $host;
          proxy_set_header        X-Forwarded-Host $host;
          proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header        X-Forwarded-Proto $scheme;
          proxy_set_header        X-Real-IP       $remote_addr;

          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_cache_bypass $http_upgrade;

          proxy_send_timeout                      3600s;
          proxy_read_timeout                      3600s;
          client_max_body_size                    10240m;

          set_escape_uri $escaped_request_uri $request_uri;
        }
        EOF
    }
    name      = "openhands-proxy-${kubernetes_namespace.this.metadata.0.name}"
    namespace = kubernetes_namespace.this.metadata.0.name
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "openhands-proxy-${kubernetes_namespace.this.metadata.0.name}"
      http {
        path {
          path      = "/"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = kubernetes_service.openhands.0.metadata.0.name
              port {
                number = kubernetes_service.openhands.0.spec.0.port.0.port
              }
            }
          }
        }
      }
    }
  }
}