variable "xoa_url" {
  description = "URL for Xen Orchestra"
  type        = string
  sensitive   = true
  default     = "wss://192.168.1.20:8443"
}

variable "xoa_username" {
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

variable "xoa_token" {
  description = "Token for Xen Orchestra"
  type        = string
  sensitive   = true
  default     = "Vx2oBsiRQIb6vRIOlytVuQoHwKFM2iG0LlmQtm5KsFA"
}