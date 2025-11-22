############################################################
# VPC CREATION
############################################################

resource "aws_vpc" "iot_vpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-iot-vpc"
  }
}

############################################################
# SUBNET
############################################################

resource "aws_subnet" "iot_subnet" {
  vpc_id                  = aws_vpc.iot_vpc.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-iot-subnet"
  }
}

############################################################
# INTERNET GATEWAY
############################################################

resource "aws_internet_gateway" "iot_igw" {
  vpc_id = aws_vpc.iot_vpc.id

  tags = {
    Name = "${var.name_prefix}-iot-igw"
  }
}

############################################################
# ROUTE TABLE AND ROUTE
############################################################

resource "aws_route_table" "iot_rt" {
  vpc_id = aws_vpc.iot_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.iot_igw.id
  }

  tags = {
    Name = "${var.name_prefix}-iot-rt"
  }
}

resource "aws_route_table_association" "iot_rta" {
  subnet_id      = aws_subnet.iot_subnet.id
  route_table_id = aws_route_table.iot_rt.id
}

############################################################
# SECURITY GROUP
############################################################

resource "aws_security_group" "sim_sg" {
  name        = "${var.name_prefix}-iot-sim-sg"
  description = "Security group for IoT simulator EC2"
  vpc_id      = aws_vpc.iot_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-iot-sg"
  }
}

############################################################
# IAM ROLE + INSTANCE PROFILE
############################################################

resource "aws_iam_role" "ec2_role" {
  name = "${var.name_prefix}-iot-sim-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "put_events_policy" {
  name = "${var.name_prefix}-put-events-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["events:PutEvents"],
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.name_prefix}-iot-sim-profile"
  role = aws_iam_role.ec2_role.name
}

############################################################
# SELECT AMI
############################################################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
}

############################################################
# EC2 INSTANCE WITH SIMULATOR SCRIPT
##########
