output "openproject_url" {
  value = aws_lb.openproject_alb.dns_name
}
