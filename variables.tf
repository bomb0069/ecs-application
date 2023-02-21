variable "name" {
  #  default     = ""
  type        = string
  description = "A name of terraform application"
}

variable "module" {
  # default     = ""
  type        = string
  description = "A name of application module"
}

variable "vpc_id" {
  #  default     = ""
  type        = string
  description = "id of VPC"
}

variable "region" {
  default     = "ap-southeast-1"
  type        = string
  description = "default region for application"
}

variable "environment" {
  default     = "dev"
  type        = string
  description = "A name of environment"
}

variable "app_version" {
  default     = "latest"
  type        = string
  description = "version of application module"
}

variable "desired_count" {
  type        = number
  default     = 0
  description = "desired_count of application module"
}
