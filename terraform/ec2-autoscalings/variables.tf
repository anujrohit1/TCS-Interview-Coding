variable "asg_name" {
  description = "Name of the Auto Scaling Group"
  type        = string
}

variable "load_balancer_url" {
  description = "URL of the Load Balancer"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy the instances"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t3.micro"
}