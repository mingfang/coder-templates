
variable "cores" {
  type    = list(any)
  default = [2, 4, 8, 16, 32, 64, 128, 256]
}

variable "memory" {
  type    = list(any)
  default = [2, 4, 8, 16, 32, 64, 128, 256]
}

variable "coder_access_url" {
  default = "http://coder.coder:7080"
}
