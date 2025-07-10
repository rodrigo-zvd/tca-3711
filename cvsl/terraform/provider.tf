# Instruct terraform to download the provider on `terraform init`
terraform {
  required_providers {
    xenorchestra = {
      source  = "vatesfr/xenorchestra"
      version = "0.32.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
  }

  backend "s3" {
  #   bucket = "terraform-state"
  #   key    = "terraform.state"
  #   region = "placeholder"

  #   endpoints = {
  #     s3 = "http://minio:9000"
  #   }

  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  #   skip_requesting_account_id  = true
  #   use_path_style              = true
  }
}

provider "xenorchestra" {
  # Must be ws or wss
  url      = var.xoa_url      # Or set XOA_URL environment variable
  username = var.xoa_username    # Or set XOA_USER environment variable
  password = var.xoa_password # Or set XOA_PASSWORD environment variable
  # XOA_USER and XOA_PASSWORD cannot be set, nor can their arguments
  # token = "Rf7dqNSsZOEGGsP14q7m8RgXH-jmx80I5C9ahsMq280" # or set XOA_TOKEN environment variable
  # This is false by default and
  # will disable ssl verification if true.
  # This is useful if your deployment uses
  # a self signed certificate but should be used sparingly!
  insecure = true # Or set XOA_INSECURE environment variable to any value
}