variable "project_name" {}
variable "tags_value" {
  type = map
}
variable "subnet" {}

variable "target_group_arn" {}

variable "name_context" {}
variable "container_port" {}
variable "image_tag" {}
variable "platform_version" {}
variable "app_memory" {}
variable "app_cpu" {}

variable "container_security_groups" {}
variable "awslogs-region" {}
variable "awslogs-stream-prefix" {}
