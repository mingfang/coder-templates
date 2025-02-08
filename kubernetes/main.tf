
data "coder_parameter" "project_dir" {
  name         = "project_dir"
  display_name = "Project Dir (after /home/coder/)"
  default      = ""
  mutable      = true
  order        = 0
}


data "coder_parameter" "workspace_image" {
  name         = "workspace_image"
  display_name = "Docker Image For Workspace"
  default      = "registry.rebelsoft.com/coder-workspace:latest"
  mutable      = true
  order        = 100
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU"
  description  = "The number of CPU cores"
  default      = "8"
  icon         = "/icon/memory.svg"
  mutable      = true
  order        = 101

  dynamic "option" {
    for_each = var.cores
    content {
      name  = "${option.value} Cores"
      value = option.value
    }
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory"
  description  = "The amount of memory in GB"
  default      = "8"
  icon         = "/icon/memory.svg"
  mutable      = true
  order        = 102

  dynamic "option" {
    for_each = var.memory
    content {
      name  = "${option.value} GB"
      value = option.value
    }
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  description  = "The size of the home disk in GB"
  default      = "20"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = true
  order        = 103
  validation {
    min       = 1
    max       = 100
    monotonic = "increasing"
  }
}


data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "pod" {
  os   = "linux"
  arch = "amd64"
  dir  = "/home/coder/${data.coder_parameter.project_dir.value}"

  env = {
    LC_ALL = "C"
  }

  startup_script = <<-EOT
    set -e    
    mkdir -p $HOME/.local/bin

    touch ~/.bash_profile
    touch ~/.bashrc

    if ! grep -q .bashrc $HOME/.bash_profile; then
    cat << EOF >> $HOME/.bash_profile
    
    source "\$HOME/.bashrc"
    EOF
    fi

    # node

    if [ ! -d "$HOME/.nvm" ]; then
      git clone https://github.com/nvm-sh/nvm.git .nvm
    fi

    if ! grep -q nvm $HOME/.bashrc; then
    cat << EOF >> $HOME/.bashrc
    
    export NVM_DIR="\$HOME/.nvm"
    [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
    [ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"
    EOF
    fi

    # python

    if [ ! -d "$HOME/.pyenv" ]; then
      curl https://pyenv.run | bash
    fi

    cat << EOF > $HOME/.pyenv_rc
    export PYENV_ROOT="\$HOME/.pyenv"
    [[ -d \$PYENV_ROOT/bin ]] && export PATH="\$PYENV_ROOT/bin:\$PATH"
    eval "\$(pyenv init -)"
    EOF
    source .pyenv_rc

    if ! grep -q pyenv $HOME/.bashrc; then
    cat << EOF >> $HOME/.bashrc

    source .pyenv_rc
    EOF
    fi

    # sdkman

    if [ ! -d "$HOME/.sdkman" ]; then
      curl -s "https://get.sdkman.io" | bash
    fi
    
    if ! grep -q sdkman $HOME/.bashrc; then
    cat << EOF >> $HOME/.bashrc
    
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    EOF
    fi


    # jupyter

    # if jupyter is enabled...
    if [ ${data.coder_parameter.jupyter.value} = true ]; then
      # if python is not installed...
      if [ $(pyenv global) == "system" ]; then
        echo "Installing Python 3.11..."
        pyenv install 3.11
        pyenv global 3.11
      fi
      # if jupyter is not installed...
      if ! command -v jupyter-lab > /dev/null 2>&1; then
        echo "Installing Jupyter..."
        pip install jupyterlab
      fi

      echo "👷 Starting Jupyter..."
      jupyter-lab --NotebookApp.ip='*' --no-browser --ServerApp.token='' --ServerApp.password='' > /tmp/jupyter.log 2>&1 &
    fi

    EOT

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic resources, you can use the `coder stat` command.
  # If you need more control, you can write your own script.
  metadata {
    display_name = "CPU"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "Uptime"
    key          = "4_uptime"
    script       = "ps -o etime= -p 1"
    interval     = 60
    timeout      = 1
  }

}
