# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.42.0"
    }
  }
  required_version = ">= 0.14.5"
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "subnet_public" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.cidr_subnet
}

resource "aws_route_table" "rtb_public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta_subnet_public" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.rtb_public.id
}

# resource "aws_security_group" "sg_22_80" {
resource "aws_security_group" "sg_22" {
  name   = "sg_22"
  vpc_id = aws_vpc.vpc.id

  # SSH access from the VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ingress {
  #   from_port   = 8080
  #   to_port     = 8080
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  # 반복문 추가
  count = 3

  # ami                         = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.subnet_public.id
  # vpc_security_group_ids      = [aws_security_group.sg_22_80.id]
  vpc_security_group_ids      = [aws_security_group.sg_22.id]
  associate_public_ip_address = true
  key_name = aws_key_pair.ansible_admin.key_name
  tags = {
    # Name = "Learn-Packer"
    Name = "ansible-${count.index}"
  }
}

# SSH Key Pair 추가
# locals {
#   private_key_filename = "${var.prefix}-ssh-key.pem"
# }

resource "aws_key_pair" "ansible_admin" {
  # key_name   = local.private_key_filename
  key_name   = "ansible_admin"
  public_key = file("~/.ssh/id_rsa.pub")
}

output "public_ip_all" {
  value = aws_instance.web.*.public_ip
}
