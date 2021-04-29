# @author: Alejandro Galue <agalue@opennms.org>

data "template_file" "zookeeper" {
  count = length(var.zookeeper_ip_addresses)

  template = file("zookeeper.tpl")

  vars = {
    node_id      = count.index + 1
    ip_addresses = join(",", var.zookeeper_ip_addresses)
    fd_limit     = var.settings.fd_limit_zookeeper
  }
}

resource "aws_instance" "zookeeper" {
  count = length(var.zookeeper_ip_addresses)

  ami           = data.aws_ami.amazon_linux_2.image_id
  instance_type = var.instance_types.zookeeper
  subnet_id     = aws_subnet.public.id
  key_name      = var.aws_key_name
  private_ip    = var.zookeeper_ip_addresses[count.index]
  user_data     = data.template_file.zookeeper.*.rendered[count.index]

  associate_public_ip_address = true # For testing purposes

  vpc_security_group_ids = [
    aws_security_group.common.id,
    aws_security_group.zookeeper.id,
  ]

  tags = {
    Name        = "Terraform Zookeeper Server ${count.index + 1}"
    Environment = "Test"
    Department  = "Support"
  }
}

output "zookeeper" {
  value = aws_instance.zookeeper.*.public_ip
}

