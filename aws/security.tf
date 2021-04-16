# @author: Alejandro Galue <agalue@opennms.org>

resource "aws_security_group" "common" {
  name        = "terraform-common-sq"
  description = "Allow basic protocols"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "SSH"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 161
    to_port     = 161
    protocol    = "udp"
    description = "SNMP"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.default.id

  tags = {
    Name        = "Terraform Common SG"
    Environment = "Test"
    Department  = "Support"
  }
}

resource "aws_security_group" "zookeeper" {
  name        = "terraform-opennms-zookeeper-sg"
  description = "Allow Zookeeper connections."

  ingress {
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    description = "Clients"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 2888
    to_port     = 2888
    protocol    = "tcp"
    description = "Peer"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 3888
    to_port     = 3888
    protocol    = "tcp"
    description = "Leader Election"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 9998
    to_port     = 9998
    protocol    = "tcp"
    description = "JMX"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.default.id

  tags = {
    Name        = "Terraform Zookeeper SG"
    Environment = "Test"
    Department  = "Support"
  }
}

resource "aws_security_group" "kafka" {
  name        = "terraform-opennms-kafka-sg"
  description = "Allow Kafka connections."

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    description = "Admin"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    description = "Clients"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9999
    to_port     = 9999
    protocol    = "tcp"
    description = "JMX"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.default.id

  tags = {
    Name        = "Terraform Kafka SG"
    Environment = "Test"
    Department  = "Support"
  }
}

resource "aws_security_group" "opennms" {
  name        = "terraform-opennms-sg"
  description = "Allow OpenNMS Core connections."

  ingress {
    from_port   = 8980
    to_port     = 8980
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 18980
    to_port     = 18980
    protocol    = "tcp"
    description = "JMX"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 61616
    to_port     = 61616
    protocol    = "tcp"
    description = "AMQ"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 8101
    to_port     = 8101
    protocol    = "tcp"
    description = "Karaf SSH"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.default.id

  tags = {
    Name        = "Terraform OpenNMS Core SG"
    Environment = "Test"
    Department  = "Support"
  }
}
