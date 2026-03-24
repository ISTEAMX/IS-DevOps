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

  owners = ["099720109477"]
}

data "aws_security_group" "backend_sg" {
  filter {
    name   = "group-name"
    values = ["isteamx-backend-sg"]
  }
}

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

resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.instance_name}-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "backend" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "isteamx-key"

  vpc_security_group_ids = [data.aws_security_group.backend_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
#!/bin/bash -xe
apt-get update
apt-get install -y docker.io docker-compose-v2 awscli
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app
cat <<EOF_ENV > .env
POSTGRES_DB=app_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
EOF_ENV
cat <<'EOF_COMPOSE' > docker-compose.yml
services:
  database:
    image: postgres:15
    restart: always
    env_file:
      - .env
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - isteamx-network

networks:
  isteamx-network:
    driver: bridge

volumes:
  postgres-data:
EOF_COMPOSE
chown -R ubuntu:ubuntu /home/ubuntu/app
docker compose up -d
EOF

  tags = {
    Name = var.instance_name
  }
}

data "aws_eip" "backend" {
  public_ip = "35.158.14.254"
}

resource "aws_eip_association" "backend_assoc" {
  instance_id   = aws_instance.backend.id
  allocation_id = data.aws_eip.backend.id
}

output "public_ip" {
  value = data.aws_eip.backend.public_ip
}

output "security_group_id" {
  value = data.aws_security_group.backend_sg.id
}