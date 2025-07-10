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
  default     = "Rf7dqNSsZOEGGsP14q7m8RgXH-jmx80I5C9ahsMq280"
}

variable "pool_name" {
  description = "Pool where will be generate XCP-ng Nested Template"
  type        = string
  sensitive   = true
  default     = "xcp-optiplex"
}

variable "pool_sr" {
  description = "Storage Repository where will be generate XCP-ng Nested Template"
  type        = string
  sensitive   = true
  default     = "Local storage"
}

variable "vm_template_vlan" {
  description = "VLAN for XCP-ng Nested Template"
  type        = string
  sensitive   = true
  default     = "LAN"
}

variable "vm_template_ip" {
  description = "IP for XCP-ng Nested Template"
  type        = string
  sensitive   = true
  default     = "192.168.1.49"
}

variable "vm_template_netmask" {
  description = "Netmask for XCP-ng Nested Template"
  type        = string
  sensitive   = true
  default     = "255.255.255.0"
}

variable "vm_template_gateway" {
  description = "Gateway for XCP-ng Nested Template"
  type        = string
  sensitive   = true
  default     = "192.168.1.1"
}

variable "vm_template_user" {
  description = "User for XCP-ng Nested Template"
  type        = string
  sensitive   = true
  default     = "root"
}

variable "vm_template_password" {
  description = "Password for XCP-ng Nested Template"
  type        = string
  sensitive   = true
  default     = "123456"
}

variable "vm_template_iso" {
  description = "ISO unattended install for XCP-ng Nested Template"
  type        = string
  sensitive   = true
  default     = "xcp-ng-8.3.0-autoinstall.iso"
}

