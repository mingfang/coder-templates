data "coder_parameter" "app" {
  name         = "app"
  display_name = "Application"
  default      = "kestra"
  mutable      = true
  order        = 100
}

data "coder_parameter" "workspace_image" {
  name         = "workspace_image"
  display_name = "Docker Image For Workspace"
  default      = "registry.rebelsoft.com/coder-workspace:latest"
  mutable      = false
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

  display_apps {
    vscode          = false
    vscode_insiders = false
    web_terminal    = true
    ssh_helper      = false
  }

  env = {
    LC_ALL = "C"
  }
  startup_script_behavior = "blocking"
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

    git -C repo pull || git clone https://github.com/mingfang/terraform-k8s-modules.git repo
    cd "repo/examples/${data.coder_parameter.app.value}"
    terraform init
    terraform apply -auto-approve
    EOT

  shutdown_script = <<-EOT
    cd "/home/coder/repo/examples/${data.coder_parameter.app.value}"
    terraform destroy -auto-approve
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
}
