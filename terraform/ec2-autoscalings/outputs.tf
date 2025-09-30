output "autoscaling_group_name" {
  value = aws_autoscaling_group.asg.name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.messages.name
}