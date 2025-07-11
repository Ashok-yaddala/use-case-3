provider "aws" {
  region = var.region
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id

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

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "openproject" {
  ami           = var.ami_id
  instance_type = "t3.medium"
  key_name      = var.key_name
  subnet_id     = aws_subnet.public_a.id
  security_groups = [aws_security_group.ec2_sg.id]

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

resource "aws_lb" "openproject_alb" {
  name               = "openproject-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "OpenProject-ALB"
  }
}

resource "aws_lb_target_group" "openproject_tg" {
  name     = "openproject-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "8080"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.openproject_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.openproject_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "openproject_attachment" {
  target_group_arn = aws_lb_target_group.openproject_tg.arn
  target_id        = aws_instance.openproject.id
  port             = 8080
}
