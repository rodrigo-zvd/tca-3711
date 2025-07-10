variable "xoa_url" {
  description = "URL for Xen Orchestra"
  type        = string
  sensitive   = true
  default     = "<YOUR XOA URL>" #must be ws or wss
}

variable "xoa_username" {
  description = "Username for Xen Orchestra"
  type        = string
  sensitive   = true
  default     = "<YOUR XOA USERNAME>"
}

variable "xoa_password" {
  description = "Password for Xen Orchestra"
  type        = string
  sensitive   = true
  default     = "<YOUR XOA PASSWORD>"
} 

variable "xoa_token" {
  description = "Token for Xen Orchestra"
  type        = string
  sensitive   = true
  default     = "<YOUR XOA TOKEN>"
}