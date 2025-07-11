provider "aws" {
  region = "ap-south-1"  # Change to your preferred region
}

resource "aws_instance" "openproject" {
  ami           = "ami-0d03cb826412c6b0f"  # Amazon Linux 2 AMI (update if needed)
  instance_type = "t3.medium"
  key_name      = "mumbai-new-aws-key"         # Replace with your EC2 key pair name

  user_data = <<-EOF
              #!/bin/bash
                sudo su
                yum update -y
                yum install docker -y
                service docker start
                systemctl enable docker
                sleep 10
                docker run -d -p 80:80 -e OPENPROJECT_SECRET_KEY_BASE=secret -e OPENPROJECT_HOST__NAME=0.0.0.0:80 -e OPENPROJECT_HTTPS=false openproject/community:12
              EOF

  tags = {
    Name = "OpenProject-Docker"
  }
}

output "openproject_url" {
  value = "http://${aws_instance.openproject.public_ip}:8080"
}
