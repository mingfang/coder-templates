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
  display_name = "Files"
  slug         = "files"
  url          = "http://localhost:13339"
  icon         = "https://raw.githubusercontent.com/matifali/logos/main/database.svg"
  subdomain    = true
  share        = "owner"
  order        = index(local.app_order, "filebrowser")

  healthcheck {
    url       = "http://localhost:13339/healthz"
    interval  = 3
    threshold = 10
  }
}