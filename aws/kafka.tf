# @author: Alejandro Galue <agalue@opennms.org>

data "template_file" "kafka" {
  count = length(var.kafka_ip_addresses)

  template = file("kafka.tpl")

  vars = {
    node_id             = count.index + 1
    num_partitions      = var.settings.kafka_num_partitions
    replication_factor  = var.settings.kafka_replication_factor
    min_insync_replicas = var.settings.kafka_min_insync_replicas
    fd_limit            = var.settings.fd_limit_kafka
    zk_ip_addresses     = join(",", var.zookeeper_ip_addresses)
    disk_device_name    = var.settings.kafka_disk_device_name
  }
}

resource "aws_instance" "kafka" {
  count = length(var.kafka_ip_addresses)

  ami           = data.aws_ami.amazon_linux_2.image_id
  instance_type = var.instance_types.kafka
  subnet_id     = aws_subnet.public.id
  key_name      = var.aws_key_name
  private_ip    = var.kafka_ip_addresses[count.index]
  user_data     = data.template_file.kafka.*.rendered[count.index]

  associate_public_ip_address = true # For testing purposes

  vpc_security_group_ids = [
    aws_security_group.common.id,
    aws_security_group.kafka.id,
  ]

  tags = {
    Name        = "Terraform Kafka Server ${count.index + 1}"
    Environment = "Test"
    Department  = "Support"
  }
}

resource "aws_ebs_volume" "kafka" {
  count = length(var.kafka_ip_addresses)

  availability_zone = data.aws_availability_zones.available.names[0]
  size              = var.settings.kafka_disk_space_in_gb
  type              = "gp2"

  tags = {
    Name        = "Terraform Kafka Volume ${count.index + 1}"
    Environment = "Test"
    Department  = "Support"
  }
}

resource "aws_volume_attachment" "kafka" {
  count = length(var.kafka_ip_addresses)

  device_name  = var.settings.kafka_disk_device_name
  volume_id    = aws_ebs_volume.kafka[count.index].id
  instance_id  = aws_instance.kafka[count.index].id
  force_detach = true
}

output "kafka" {
  value = aws_instance.kafka.*.public_ip
}

