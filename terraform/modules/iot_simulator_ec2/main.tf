# -------------------------------
# VPC
# -------------------------------
resource "aws_vpc" "iot_vpc" {
  cidr_block           = "10.50.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "iot_subnet" {
  vpc_id                  = aws_vpc.iot_vpc.id
  cidr_block              = "10.50.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.iot_vpc.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.iot_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rt_assoc" {
  subnet_id      = aws_subnet.iot_subnet.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.iot_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------------
# IAM for EC2 Simulator
# -------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "${var.name_prefix}-iot-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole",
      Effect    = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "put_events" {
  name = "${var.name_prefix}-put-events-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = ["events:PutEvents"],
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.name_prefix}-iot-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# -------------------------------
# AMI
# -------------------------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# -------------------------------
# EC2 IoT Simulator
# -------------------------------
resource "aws_instance" "iot_sim" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.iot_subnet.id
  vpc_security_group_ids = [aws_security_group.sg.id]
  iam_instance_profile   = aws_iam_instance_profile.profile.name

  user_data = <<EOF
#!/bin/bash
yum update -y
yum install -y python3 pip
pip3 install boto3

cat > /opt/iot_sim.py << 'PYEOF'
import json, random, time, boto3
client = boto3.client("events", region_name="${var.region}")
while True:
    event = {
        "Source": "cet11.grp1.iot",
        "DetailType": "iot.telemetry",
        "Detail": json.dumps({
            "device_id": "sensor-01",
            "temperature": round(random.uniform(20, 40), 2),
            "humidity": round(random.uniform(40, 90), 2)
        })
    }
    client.put_events(Entries=[event])
    time.sleep(10)
PYEOF

nohup python3 /opt/iot_sim.py &
EOF
}
