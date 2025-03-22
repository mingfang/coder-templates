data "coder_parameter" "nodejs_version" {
  name         = "nodejs-version"
  display_name = "Install Node.js version."
  default      = ""
  mutable      = true
  order        = 10
}

resource "coder_script" "nodejs" {
  agent_id     = coder_agent.pod.id
  display_name = "nodejs"
  run_on_start = true
  script       = <<-EOF
  if [ ! -d "$HOME/.nvm" ]; then
    git clone https://github.com/nvm-sh/nvm.git $HOME/.nvm
  else
    git -C $HOME/.nvm pull
  fi

  if ! grep -q nvm $HOME/.bashrc; then
  cat << EOF2 >> $HOME/.bashrc

  export NVM_DIR="\$HOME/.nvm"
  [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
  [ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"
  EOF2
  fi

  if [ -n "${data.coder_parameter.nodejs_version.value}" ]; then
    nvm install "${data.coder_parameter.nodejs_version.value}"
    nvm use "${data.coder_parameter.nodejs_version.value}"
  fi
  EOF
}