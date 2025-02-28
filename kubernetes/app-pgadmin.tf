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