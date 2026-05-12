variable "instance_name" {
  description = "The name of the EC2 instance."
  type        = string
}

variable "secret_arn" {
  description = "ARN of the Secrets Manager secret containing application secrets."
  type        = string
}

variable "backend_eip" {
  description = "The public IP address of the pre-allocated Elastic IP for the backend."
  type        = string
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

data "aws_security_group" "backend_sg" {
  filter {
    name   = "group-name"
    values = ["isteamx-backend-sg"]
  }
}

data "aws_region" "current" {}

data "aws_eip" "backend" {
  public_ip = var.backend_eip
}

data "aws_subnets" "default" {
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "backend_8080" {
  security_group_id = data.aws_security_group.backend_sg.id

  description = "Backend API - restrict to known sources in production"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 8080
  ip_protocol = "tcp"
  to_port     = 8080
}

# ─────────────────────────────────────────────────
# IAM Role & Policies
# ─────────────────────────────────────────────────

resource "aws_iam_role" "ec2_role" {
  name = "${var.instance_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name    = "${var.instance_name}-role"
    Project = "isteamx"
  }
}

resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "secrets_manager_read" {
  name = "${var.instance_name}-secrets-read"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "secretsmanager:GetSecretValue"
      ],
      Resource = var.secret_arn
    }]
  })
}

resource "aws_iam_role_policy" "cloudwatch_write" {
  name = "${var.instance_name}-cloudwatch-write"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "cloudwatch:PutMetricData"
      ],
      Resource = [
        "arn:aws:logs:*:*:log-group:/isteamx/*",
        "arn:aws:logs:*:*:log-group:/isteamx/*:*"
      ]
    },
    {
      Effect   = "Allow",
      Action   = ["cloudwatch:PutMetricData"],
      Resource = "*",
      Condition = {
        StringEquals = {
          "cloudwatch:namespace" = "isteamx-backend"
        }
      }
    }]
  })
}

# Policy to allow the instance to associate the Elastic IP on boot
resource "aws_iam_role_policy" "eip_associate" {
  name = "${var.instance_name}-eip-associate"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "ec2:AssociateAddress",
        "ec2:DescribeAddresses"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.instance_name}-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name    = "${var.instance_name}-profile"
    Project = "isteamx"
  }
}

# ─────────────────────────────────────────────────
# Launch Template (replaces aws_instance)
# ─────────────────────────────────────────────────

resource "aws_launch_template" "backend" {
  name_prefix   = "${var.instance_name}-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "isteamx-key-ec2"

  vpc_security_group_ids = [data.aws_security_group.backend_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
      volume_type = "gp3"
    }
  }

  user_data = base64encode(<<-EOF
#!/bin/bash -xe
# Retry apt operations to handle transient mirror errors
apt-get update -o Acquire::Retries=5
apt-get install -y -o Acquire::Retries=5 docker.io awscli jq
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Get instance ID using IMDSv2 token
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

# Wait for IAM instance profile to be ready
echo "Waiting for IAM role to propagate..."
sleep 15

# Associate the Elastic IP to this instance (with retries)
ALLOCATION_ID="${data.aws_eip.backend.id}"
for i in 1 2 3 4 5; do
  aws ec2 associate-address \
    --instance-id "$INSTANCE_ID" \
    --allocation-id "$ALLOCATION_ID" \
    --region "${data.aws_region.current.name}" && break
  echo "EIP association attempt $i failed, retrying in 10s..."
  sleep 10
done

mkdir -p /home/ubuntu/app
cd /home/ubuntu/app

# Fetch application secrets from AWS Secrets Manager
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "${var.secret_arn}" \
  --region "${data.aws_region.current.name}" \
  --query 'SecretString' \
  --output text)

# Write each key-value pair from the JSON secret into a .env file
echo "$SECRET_JSON" | jq -r 'to_entries[] | "\(.key)=\(.value)"' > .env

chown -R ubuntu:ubuntu /home/ubuntu/app
docker network create isteamx-network || true
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = var.instance_name
      Project = "isteamx"
    }
  }

  tags = {
    Name    = "${var.instance_name}-lt"
    Project = "isteamx"
  }
}

# ─────────────────────────────────────────────────
# Auto Scaling Group — self-healing (min=1, max=1)
# ─────────────────────────────────────────────────

resource "aws_autoscaling_group" "backend" {
  name                = "${var.instance_name}-asg"
  min_size            = 0
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = data.aws_subnets.default.ids

  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  # Wait for instance to be healthy before marking ASG as updated
  wait_for_capacity_timeout = "10m"

  tag {
    key                 = "Name"
    value               = var.instance_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "isteamx"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─────────────────────────────────────────────────
# Outputs
# ─────────────────────────────────────────────────

output "public_ip" {
  value = data.aws_eip.backend.public_ip
}

output "security_group_id" {
  value = data.aws_security_group.backend_sg.id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.backend.name
}
