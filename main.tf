provider "aws" {
  region = "ap-south-1"  # Change to your preferred region
}

resource "aws_instance" "openproject" {
  ami           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2 AMI (update if needed)
  instance_type = "t2.medium"
  key_name      = "mumbai-new-aws-key"         # Replace with your EC2 key pair name

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo amazon-linux-extras install docker -y
              sudo service docker start
              sudo usermod -a -G docker ec2-user
              docker run -d -p 8080:80 openproject/community:latest
              EOF

  tags = {
    Name = "OpenProject-Docker"
  }
}

output "openproject_url" {
  value = "http://${aws_instance.openproject.public_ip}:8080"
}
