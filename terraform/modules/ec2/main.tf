variable "instance_name" {
  description = "The name of the EC2 instance."
  type        = string
}

# Data source to find the latest Ubuntu AMI
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

  owners = ["099720109477"] # Canonical's owner ID
}

# Security Group to control firewall rules
resource "aws_security_group" "backend_sg" {
  name        = "${var.instance_name}-sg"
  description = "Allow HTTP from anywhere. SSH is managed by the CI/CD pipeline."

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }
}

# IAM Role that allows the EC2 instance to be managed by AWS and access ECR
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
}

# Attach the AWS-managed policy that grants read-only access to ECR
resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Create an instance profile to attach the role to the EC2 instance
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.instance_name}-profile"
  role = aws_iam_role.ec2_role.name
}

# The EC2 Instance itself
resource "aws_instance" "backend" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "isteamx-key"

  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data     = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y docker.io amazon-ecr-credential-helper
              sudo usermod -aG docker ubuntu

              # Configure Docker to use the ECR credential helper
              sudo mkdir -p /home/ubuntu/.docker
              echo '{ "credsStore": "ecr-login" }' | sudo tee /home/ubuntu/.docker/config.json
              sudo chown -R ubuntu:ubuntu /home/ubuntu/.docker

              # Restart Docker to apply changes
              sudo systemctl restart docker
              EOF

  tags = {
    Name = var.instance_name
  }
}

# The static Elastic IP
resource "aws_eip" "backend" {
  instance = aws_instance.backend.id
  domain   = "vpc"
}

# Output the static IP
output "public_ip" {
  description = "The static public IP address of the EC2 instance."
  value       = aws_eip.backend.public_ip
}

# Output the Security Group ID so the workflow can use it
output "security_group_id" {
  description = "The ID of the backend security group."
  value       = aws_security_group.backend_sg.id
}
