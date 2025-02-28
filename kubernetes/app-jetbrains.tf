data "coder_parameter" "jetbrains" {
  name         = "jetbrains"
  display_name = "JetBrains"
  type         = "bool"
  default      = true
  mutable      = true
  order        = index(local.app_order, "jetbrains")
}

resource "coder_app" "jetbrains" {
  count        = data.coder_parameter.jetbrains.value ? data.coder_workspace.me.start_count : 0
  display_name = "JetBrains"
  slug         = "jb"
  icon         = "/icon/gateway.svg"
  external     = true
  url = join("", [
    "jetbrains-gateway://connect#type=coder",
    "&workspace=", data.coder_workspace.me.name,
    "&agent=", "pod",
    "&url=", data.coder_workspace.me.access_url,
    "&token=", "$SESSION_TOKEN",
  ])
  agent_id = coder_agent.pod.id
  order    = index(local.app_order, "jetbrains")
}