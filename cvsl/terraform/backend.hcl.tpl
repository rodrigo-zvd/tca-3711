backend "s3" {
  bucket = "terraform-state"
  key    = "terraform.state"
  region = "placeholder"

  endpoints = {
    s3 = "{{ .Env.MINIO_ENDPOINT }}"
  }

  access_key = "{{ .Env.MINIO_ACCESS_KEY }}"
  secret_key = "{{ .Env.MINIO_SECRET_KEY }}"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  use_path_style              = true
}