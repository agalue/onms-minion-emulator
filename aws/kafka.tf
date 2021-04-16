# @author: Alejandro Galue <agalue@opennms.org>

data "template_file" "kafka" {
  count = length(var.kafka_ip_addresses)

  template = file("kafka.tpl")

  vars = {
    node_id             = count.index + 1
    num_partitions      = var.settings.kafka_num_partitions
    replication_factor  = var.settings.kafka_replication_factor
    min_insync_replicas = var.settings.kafka_min_insync_replicas
    ip_addresses        = join(",", var.kafka_ip_addresses)
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
    aws_security_group.zookeeper.id,
    aws_security_group.kafka.id,
  ]

  root_block_device {
    volume_type = "gp2"
    volume_size = var.settings.kafka_disk_space
  }

  tags = {
    Name        = "Terraform Kafka Server ${count.index + 1}"
    Environment = "Test"
    Department  = "Support"
  }
}

output "kafka" {
  value = aws_instance.kafka.*.public_ip
}

