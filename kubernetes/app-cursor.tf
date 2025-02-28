data "coder_parameter" "cursor" {
  name         = "cursor"
  display_name = "Cursor Desktop"
  type         = "bool"
  default      = true
  mutable      = true
  order        = index(local.app_order, "cursor")
}

module "cursor" {
  count    = data.coder_parameter.cursor.value ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/modules/cursor/coder"
  version  = "1.0.19"
  agent_id = coder_agent.pod.id
  folder   = "/home/coder/${data.coder_parameter.project_dir.value}"
  order    = index(local.app_order, "cursor")
}