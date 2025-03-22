resource "coder_script" "personalize" {
  agent_id     = coder_agent.pod.id
  display_name = "personalize"
  run_on_start = true
  script       = <<-EOF
  touch ~/personalize
  chmod +x ~/personalize
  EOF
}

module "personalize" {
  count      = data.coder_workspace.me.start_count
  source     = "registry.coder.com/modules/personalize/coder"
  version    = "1.0.2"
  agent_id   = coder_agent.pod.id
  log_path   = "/tmp/personalize.log"
  depends_on = [coder_script.personalize]
}