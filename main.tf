provider "aws" {
  region = "ap-south-1"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "OpenProject-VPC"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
  tags = {
    Name = "Public-Subnet"
  }
}

# Public Subnet in a different Availability Zone
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1b"
  tags = {
    Name = "Public-Subnet-2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {    
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group with dynamic block
resource "aws_security_group" "instance_sg" {
  name   = "instance-sg"
  vpc_id = aws_vpc.main.id
  dynamic "ingress" {
    for_each = var.ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EC2-SG"
  }
}

// alb for openproject
resource "aws_lb"  "app_lb_open" {
  name               = "openproject-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.instance_sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_2.id]
}

# ALB Target Groups for oepn project
resource "aws_lb_target_group" "openproject_tg" {
  name     = "openproject-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"       # Try changing to "/login" if needed
    protocol            = "HTTP"
    matcher             = "200"     # Expect HTTP 200
    interval            = 30        # Time between checks
    timeout             = 5         # Timeout for each check
    healthy_threshold   = 2         # # of consecutive successes
    unhealthy_threshold = 2         # # of consecutive failures
  }
}

# ALB Listener & Rules for OpenProject
resource "aws_lb_listener" "listener_openproject" {
  load_balancer_arn = aws_lb.app_lb_open.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.openproject_tg.arn
  }
}

# EC2 Instance - OpenProject
resource "aws_instance" "openproject" {
  ami           = "ami-0a1235697f4afa8a4"
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true
  user_data = <<-EOT
              #!/bin/bash
              sudo
              yum update -y
              yum install docker -y
              service docker start
              systemctl enable docker
              sleep 60
              docker run -d -p 80:80 -e OPENPROJECT_SECRET_KEY_BASE=secret -e OPENPROJECT_HOST__NAME=0.0.0.0:80 -e OPENPROJECT_HTTPS=false openproject/community:12
              EOT

  tags = merge(var.tags, {
    Name = "${lookup(var.tags, "Name", "default")}-OpenProject"
  })
}

# Register Targets
resource "aws_lb_target_group_attachment" "openproject_attachment" {
  target_group_arn = aws_lb_target_group.openproject_tg.arn
  target_id        = aws_instance.openproject.id
  port             = 80
}