locals {
  app_order = [
    "app",
    "vscode",
    "filebrowser",
  ]
}

# app

locals {
  url = "https://${local.name}.rebelsoft.com"
}

resource "coder_app" "app" {
  agent_id     = coder_agent.pod.id
  display_name = data.coder_parameter.app.value
  slug         = "a"
  icon         = "/icon/widgets.svg"
  external     = true
  order        = index(local.app_order, "app")

  url = local.url
  open_in = "tab"
}

# vscode

data "coder_parameter" "vscode" {
  name         = "vscode"
  display_name = "VS Code Web"
  type         = "bool"
  default      = false
  mutable      = true
  order        = index(local.app_order, "vscode")
}

# vscode web
module "vscode-web" {
  count        = data.coder_parameter.vscode.value ? 1 : 0
  source         = "registry.coder.com/modules/vscode-web/coder"
  version        = "1.0.26"
  agent_id       = coder_agent.pod.id
  accept_license = true
}

# filebrowser

data "coder_parameter" "filebrowser" {
  name         = "filebrowser"
  display_name = "Files"
  type         = "bool"
  default      = false
  mutable      = true
  order        = index(local.app_order, "filebrowser")
}

resource "coder_app" "filebrowser" {
  count        = data.coder_parameter.filebrowser.value ? 1 : 0
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
