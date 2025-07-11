provider "aws" {
 region = "ap-south-1"
}
resource "aws_key_pair" "openproject_key" {
 key_name   = "openproject-key"
 public_key = file("~/.ssh/openproject-key.pub") # Change path if needed
}
resource "aws_vpc" "main" {
 cidr_block = "10.0.0.0/16"
}
resource "aws_internet_gateway" "gw" {
 vpc_id = aws_vpc.main.id
}
resource "aws_subnet" "public" {
 vpc_id                  = aws_vpc.main.id
 cidr_block              = "10.0.1.0/24"
 map_public_ip_on_launch = true
}
resource "aws_route_table" "rt" {
 vpc_id = aws_vpc.main.id
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.gw.id
 }
}
resource "aws_route_table_association" "rta" {
 subnet_id      = aws_subnet.public.id
 route_table_id = aws_route_table.rt.id
}
resource "aws_security_group" "openproject_sg" {
 name   = "openproject-sg"
 vpc_id = aws_vpc.main.id
 ingress {
   from_port   = 80
   to_port     = 80
   protocol    = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
 }
 egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}
resource "aws_instance" "openproject" {
 ami                    = "ami-0f918f7e67a3323f0" # Ubuntu 22.04 LTS for ap-south-1
 instance_type          = "t2.medium"
 subnet_id              = aws_subnet.public.id
 vpc_security_group_ids = [aws_security_group.openproject_sg.id]
 key_name               = aws_key_pair.openproject_key.key_name
 user_data = <<-EOF
             #!/bin/bash
             apt-get update -y
             apt-get install -y docker.io
             systemctl start docker
             systemctl enable docker
             docker run -d -p 80:80 openproject/community:latest
             EOF
 tags = {
   Name = "OpenProject-Server"
 }
}