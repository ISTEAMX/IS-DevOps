variable "instance_name" {
  description = "The name of the EC2 instance."
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

  owners = ["099720109477"] # Canonical's owner ID
}

resource "aws_security_group" "backend_sg" {
  name        = "${var.instance_name}-sg"
  description = "Allow HTTP from anywhere. SSH is managed by the CI/CD pipeline."

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
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

resource "aws_instance" "backend" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "isteamx-key"

  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  user_data     = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y docker.io
              sudo usermod -aG docker ubuntu
              EOF

  tags = {
    Name = var.instance_name
  }
}

resource "aws_eip" "backend" {
  instance = aws_instance.backend.id
  domain   = "vpc"
}

output "public_ip" {
  description = "The static public IP address of the EC2 instance."
  value       = aws_eip.backend.public_ip
}

output "security_group_id" {
  description = "The ID of the backend security group."
  value       = aws_security_group.backend_sg.id
}
