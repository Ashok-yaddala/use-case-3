variable "region" {
  default = "ap-south-1"
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  default     = "mumbai-new-aws-key"  # Replace with your actual key pair name
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI ID"
  default     = "ami-0d03cb826412c6b0f"  # Update if needed for your region
}
