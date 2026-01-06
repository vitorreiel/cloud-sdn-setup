variable "aws_access_key" {
  type        = string
  description = "AWS access key"
  default = ""
}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key"
  default = ""
}

variable "aws_session_token" {
  type        = string
  description = "AWS session token"
  default = ""
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "image" {
  type        = string
  default     = "ami-007855ac798b5175e"
  description = "AMI ID for the instance"
}

variable "security_group_name" {
  type        = string
  default     = "containernet-group"
  description = "Name of the security group"
}

variable "key_name" {
  type        = string
  default     = "containernet-keypair"
  description = "Name of the key pair"
}

variable "instance_name" {
  type        = string
  default     = "Containernet"
  description = "Name of the EC2 instance"
}
