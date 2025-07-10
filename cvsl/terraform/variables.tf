variable "xoa_url" {
  description = "URL for Xen Orchestra"
  type        = string
  sensitive   = true
  default     = "wss://192.168.1.20:8443"
}

variable "xoa_user" {
  description = "Username for Xen Orchestra"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "xoa_password" {
  description = "Password for Xen Orchestra"
  type        = string
  sensitive   = true
  default     = "m3gaFox50"
}