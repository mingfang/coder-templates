data "coder_parameter" "jupyter" {
  name         = "jupyter"
  display_name = "Jupyter"
  type         = "bool"
  default      = false
  mutable      = true
  order        = index(local.app_order, "jupyter")
}

resource "coder_app" "jupyterlab" {
  count        = data.coder_parameter.jupyter.value ? data.coder_workspace.me.start_count : 0
  agent_id     = coder_agent.pod.id
  slug         = "jupyterlab"
  display_name = "JupyterLab"
  url          = "http://localhost:8888"
  icon         = "/icon/jupyter.svg"
  subdomain    = true
  share        = "owner"
  order        = index(local.app_order, "jupyter")

  healthcheck {
    url       = "http://localhost:8888/healthz"
    interval  = 5
    threshold = 10
  }
}