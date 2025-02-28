data "coder_parameter" "vscode" {
  name         = "vscode"
  display_name = "VS Code Web"
  type         = "bool"
  default      = true
  mutable      = true
  order        = index(local.app_order, "vscode")
}

module "vscode-web" {
  count          = data.coder_parameter.vscode.value ? data.coder_workspace.me.start_count : 0
  source         = "registry.coder.com/modules/vscode-web/coder"
  version        = "1.0.30"
  accept_license = true
  agent_id       = coder_agent.pod.id
  folder         = "/home/coder/${data.coder_parameter.project_dir.value}"
  order          = index(local.app_order, "vscode")
}