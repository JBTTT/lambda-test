data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "sim_sg" {
  name        = "${var.name_prefix}-iot-sim-sg"
  description = "Security group for IoT simulator EC2"
  vpc_id      = data.aws_vpc.default.id

  # allow outbound only
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

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

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
}

resource "aws_instance" "iot_simulator" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.sim_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "${var.name_prefix}-iot-simulator"
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3 pip

    pip3 install boto3 -q

    cat > /opt/iot_simulator.py << 'PYEOF'
    import boto3
    import json
    import random
    import time

    REGION = "${var.region}"
    SOURCE = "cet11.grp1.iot"
    DETAIL_TYPE = "iot.telemetry"

    client = boto3.client("events", region_name=REGION)

    def send_event():
        event = {
            "Source": SOURCE,
            "DetailType": DETAIL_TYPE,
            "Detail": json.dumps({
                "device_id": "sensor-01",
                "temperature": round(random.uniform(20.0, 40.0), 2),
                "humidity": round(random.uniform(40.0, 90.0), 2)
            }),
        }
        response = client.put_events(Entries=[event])
        print("Sent IoT event:", event, "Response:", response)

    if __name__ == "__main__":
        while True:
            try:
                send_event()
            except Exception as e:
                print("Error sending event:", e)
            time.sleep(10)
    PYEOF

    nohup python3 /opt/iot_simulator.py > /var/log/iot_simulator.log 2>&1 &
  EOF
}
