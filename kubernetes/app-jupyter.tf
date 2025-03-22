data "coder_parameter" "jupyter" {
  name         = "jupyter"
  display_name = "Jupyter"
  type         = "bool"
  default      = false
  mutable      = true
  order        = index(local.app_order, "jupyter")
}

resource "coder_script" "jupyter" {
  count        = data.coder_parameter.jupyter.value ? 1 : 0
  agent_id     = coder_agent.pod.id
  display_name = "jupyter"
  run_on_start = true
  script       = <<-EOF
  until [ -e /tmp/coder_script.python ]; do
    echo "Waiting for /tmp/coder_script.python..."
    sleep 3
  done

  echo "Installing Jupyter..."
  pip install -U jupyterlab

  echo "👷 Starting Jupyter..."
  SHELL=/bin/bash jupyter-lab --NotebookApp.ip='*' --no-browser --ServerApp.token='' --ServerApp.password='' > /tmp/jupyter.log 2>&1 &
  EOF

  depends_on = [coder_script.python]
}

resource "coder_app" "jupyter" {
  count        = data.coder_parameter.jupyter.value ? data.coder_workspace.me.start_count : 0
  agent_id     = coder_agent.pod.id
  slug         = "jupyter"
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