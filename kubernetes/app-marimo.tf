data "coder_parameter" "marimo" {
  name         = "marimo"
  display_name = "Marimo"
  type         = "bool"
  default      = false
  mutable      = true
  order        = index(local.app_order, "marimo")
}

resource "coder_script" "marimo" {
  count        = data.coder_parameter.marimo.value ? 1 : 0
  agent_id     = coder_agent.pod.id
  display_name = "marimo"
  run_on_start = true
  script       = <<-EOF
  until [ -e /tmp/coder_script.python ]; do
    echo "Waiting for /tmp/coder_script.python..."
    sleep 3
  done

  echo "Installing Marimo..."
  pip install -U marimo[recommended]

  echo "👷 Starting Marimo..."
  SHELL=/bin/bash marimo edit --port 2718 --headless --no-token > /tmp/marimo.log 2>&1 &
  EOF

  depends_on = [coder_script.python]
}

resource "coder_app" "marimo" {
  count        = data.coder_parameter.marimo.value ? data.coder_workspace.me.start_count : 0
  agent_id     = coder_agent.pod.id
  slug         = "marimo"
  display_name = "Marimo"
  url          = "http://localhost:2718"
  icon         = "https://raw.githubusercontent.com/marimo-team/marimo/refs/heads/main/docs/_static/favicon-32x32.png"
  subdomain    = true
  share        = "owner"
  order        = index(local.app_order, "marimo")

  healthcheck {
    url       = "http://localhost:2718/health"
    interval  = 5
    threshold = 10
  }
}