terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "EC2 instance type (free-tier: t3.micro in eu-north-1, t2.micro elsewhere)"
  type        = string
  default     = "t3.micro"
}

variable "public_key_path" {
  description = "Path to the SSH public key uploaded to the instance"
  type        = string
  default     = "~/.ssh/cs411-ec2.pub"
}

# SSH (22) ingress. Deploy phase: include the Jenkins playground IP so the
# pipeline can ssh in. Hardening phase: narrow to just your laptop IP.
variable "ssh_ingress_cidrs" {
  description = "CIDRs allowed to reach tcp/22"
  type        = list(string)
  default     = ["0.0.0.0/0"] # tighten to ["<your-laptop-ip>/32"] after deploy
}

# ---------------------------------------------------------------------------
# Latest Ubuntu 22.04 AMI (Canonical), region-agnostic
# ---------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# Key pair
# ---------------------------------------------------------------------------
resource "aws_key_pair" "cs411" {
  key_name   = "cs411-ec2"
  public_key = file(pathexpand(var.public_key_path))
}

# ---------------------------------------------------------------------------
# Security group: 4444 open to the world, 22 limited to ssh_ingress_cidrs
# ---------------------------------------------------------------------------
resource "aws_security_group" "myapp" {
  name        = "cs411-myapp-sg"
  description = "Allow app traffic on 4444 and restricted SSH"

  ingress {
    description = "App"
    from_port   = 4444
    to_port     = 4444
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH (narrow this after the deploy)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Cohort = "CS411-2026"
    Owner  = "maydamv"
  }
}

# ---------------------------------------------------------------------------
# EC2 instance (t2.micro, free-tier)
# ---------------------------------------------------------------------------
resource "aws_instance" "myapp" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.cs411.key_name
  vpc_security_group_ids = [aws_security_group.myapp.id]

  tags = {
    Name   = "cs411-myapp"
    Cohort = "CS411-2026"
    Owner  = "maydamv"
  }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "public_ip" {
  description = "Public IP — paste into iximiuz and pass as EC2_IP to the pipeline"
  value       = aws_instance.myapp.public_ip
}
