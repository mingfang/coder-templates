data "coder_parameter" "python_version" {
  name         = "python-version"
  display_name = "Install Python version."
  default      = ""
  mutable      = true
  order        = 11
}

locals {
  DEFAULT_PYTHON_VERSION = data.coder_parameter.jupyter.value || data.coder_parameter.marimo.value ? "3.11" : ""
  PYTHON_VERSION         = data.coder_parameter.python_version.value == "" ? local.DEFAULT_PYTHON_VERSION : data.coder_parameter.python_version.value
}

resource "coder_script" "python" {
  agent_id     = coder_agent.pod.id
  display_name = "python"
  run_on_start = true
  script       = <<-EOF
  if [ ! -d "$HOME/.pyenv" ]; then
    curl https://pyenv.run | bash
  else
    git -C $HOME/.pyenv pull
  fi

  cat << EOF2 > $HOME/.pyenv_rc
  export PYENV_ROOT="\$HOME/.pyenv"
  [[ -d \$PYENV_ROOT/bin ]] && export PATH="\$PYENV_ROOT/bin:\$PATH"
  eval "\$(pyenv init -)"
  EOF2
  source $HOME/.pyenv_rc

  if ! grep -q pyenv $HOME/.bashrc; then
  cat << EOF2 >> $HOME/.bashrc
  
  source \$HOME/.pyenv_rc
  EOF2
  fi

  if [ -n "${local.PYTHON_VERSION}" ]; then
    pyenv install "${local.PYTHON_VERSION}"
    pyenv global "${local.PYTHON_VERSION}"
  fi

  # signal to other scripts
  touch /tmp/coder_script.python
  EOF
}