variable "region" {
  type = string
  default = "ap-southeast-1"
}
variable "bucket_name" {
  type = string
  default = "terraform-state"
}

variable "global_tag" {
  type = map
  default = {
    ManagedBy = "Terraform"
  }
}

variable "project_tag" {
  type = map
}