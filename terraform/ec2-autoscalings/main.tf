data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_cloudwatch_log_group" "messages" {
  name              = "/ec2/messages"
  retention_in_days = 30
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.asg_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.asg_name}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

data "template_file" "user_data" {
  template = <<-EOF
              #!/bin/bash
              dnf install -y nginx amazon-cloudwatch-agent
              systemctl enable nginx
              systemctl start nginx

              # CloudWatch agent config
              cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json <<EOL
              {
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/messages",
                          "log_group_name": "/ec2/messages",
                          "log_stream_name": "{instance_id}"
                        }
                      ]
                    }
                  }
                }
              }
              EOL

              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s

              # Optional: log LB URL
              echo "Load Balancer URL: ${var.load_balancer_url}" >> /var/log/messages
            EOF
}

resource "aws_launch_template" "lt" {
  name_prefix   = "${var.asg_name}-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(data.template_file.user_data.rendered)

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  name                      = var.asg_name
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = var.asg_name
    propagate_at_launch = true
  }

  # Force instance replacement every 30 days
  scheduled_action {
    name                  = "rotate-instance"
    recurrence            = "0 0 */30 * *" # every 30 days
    min_size              = 1
    max_size              = 1
    desired_capacity      = 0
    time_zone             = "UTC"
    start_time            = formatdate("YYYY-MM-DDT00:00:00Z", timestamp())
  }

  depends_on = [aws_launch_template.lt]
}

resource "aws_security_group" "ec2_sg" {
  name        = "${var.asg_name}-sg"
  description = "Allow SSM and HTTP"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Nginx (for internal use, e.g., LB to EC2)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] # Adjust for your private VPC CIDR
  }

  # SSM ports not needed, but must allow HTTPS for agent
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}