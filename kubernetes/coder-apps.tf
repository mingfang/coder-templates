locals {
  app_order = [
    "vscode",
    "jetbrains",
    "jupyter",
    "pgadmin",
    "filebrowser",
  ]
}

# vscode

data "coder_parameter" "vscode" {
  name         = "vscode"
  display_name = "VS Code Web"
  type         = "bool"
  default      = true
  mutable      = true
  order = index(local.app_order, "vscode")
}

# vscode web
module "vscode-web" {
  count          = data.coder_parameter.vscode.value ? 1 : 0
  source         = "registry.coder.com/modules/vscode-web/coder"
  version        = "1.0.26"
  agent_id       = coder_agent.pod.id
  accept_license = true
}

# jetbrains

data "coder_parameter" "jetbrains" {
  name         = "jetbrains"
  display_name = "JetBrains"
  type         = "bool"
  default      = true
  mutable      = true
  order = index(local.app_order, "jetbrains")
}

resource "coder_app" "jetbrains" {
  count        = data.coder_parameter.jetbrains.value ? 1 : 0
  agent_id     = coder_agent.pod.id
  display_name = "JetBrains"
  slug         = "jb"
  icon         = "/icon/gateway.svg"
  external     = true
  order = index(local.app_order, "jetbrains")

  url = join("", [
    "jetbrains-gateway://connect#type=coder",
    "&workspace=", data.coder_workspace.me.name,
    "&agent=", "pod",
    "&url=", data.coder_workspace.me.access_url,
    "&token=", "$SESSION_TOKEN",
  ])
}

# jupyter

data "coder_parameter" "jupyter" {
  name         = "jupyter"
  display_name = "Jupyter"
  type         = "bool"
  default      = false
  mutable      = true
  order = index(local.app_order, "jupyter")
}

resource "coder_app" "jupyterlab" {
  count        = data.coder_parameter.jupyter.value ? 1 : 0
  agent_id     = coder_agent.pod.id
  slug         = "jupyterlab"
  display_name = "JupyterLab"
  url          = "http://localhost:8888"
  icon         = "/icon/jupyter.svg"
  subdomain    = true
  share        = "owner"
  order = index(local.app_order, "jupyter")

  healthcheck {
    url       = "http://localhost:8888/healthz"
    interval  = 5
    threshold = 10
  }
}

# pgadmin

data "coder_parameter" "pgadmin" {
  name         = "pgadmin"
  display_name = "PGAdmin"
  type         = "bool"
  default      = false
  mutable      = true
  order = index(local.app_order, "pgadmin")
}

resource "coder_app" "pgadmin" {
  count        = data.coder_parameter.pgadmin.value ? 1 : 0
  agent_id     = coder_agent.pod.id
  slug         = "pgadmin"
  display_name = "pgAdmin"
  icon         = "https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/Postgresql_elephant.svg/1200px-Postgresql_elephant.svg.png"
  url          = "http://localhost:5050"
  subdomain    = true
  share        = "owner"
  order = index(local.app_order, "pgadmin")

  healthcheck {
    url       = "http://localhost:5050/misc/ping"
    interval  = 3
    threshold = 10
  }
}

# filebrowser

data "coder_parameter" "filebrowser" {
  name         = "filebrowser"
  display_name = "Files"
  type         = "bool"
  default      = true
  mutable      = true
  order = index(local.app_order, "filebrowser")
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
  order = index(local.app_order, "filebrowser")

  healthcheck {
    url       = "http://localhost:13339/healthz"
    interval  = 3
    threshold = 10
  }
}
