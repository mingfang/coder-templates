data "coder_parameter" "rclone" {
  name         = "rclone"
  display_name = "Rclone"
  type         = "bool"
  default      = false
  mutable      = true
  order        = index(local.app_order, "rclone")
}

resource "coder_app" "rclone" {
  count        = data.coder_parameter.rclone.value ? data.coder_workspace.me.start_count : 0
  agent_id     = coder_agent.pod.id
  slug         = "rclone"
  display_name = "Rclone"
  url          = "http://localhost:5572"
  icon         = "/icon/filebrowser.svg"
  subdomain    = true
  share        = "owner"
  order        = index(local.app_order, "rclone")

  healthcheck {
    url       = "http://localhost:5572"
    interval  = 5
    threshold = 10
  }
}