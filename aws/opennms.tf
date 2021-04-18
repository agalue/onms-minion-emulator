# @author: Alejandro Galue <agalue@opennms.org>

data "template_file" "opennms" {
  template = file("opennms.tpl")

  vars = {
    zk_servers    = "${aws_instance.kafka[0].private_ip}:2181"
    kafka_servers = "${aws_instance.kafka[0].private_ip}:9092"
    rpc_ttl       = var.settings.onms_rpc_ttl
  }
}

resource "aws_instance" "opennms" {
  ami           = data.aws_ami.amazon_linux_2.image_id
  instance_type = var.instance_types.opennms
  subnet_id     = aws_subnet.public.id
  key_name      = var.aws_key_name
  private_ip    = var.onms_ip_address
  user_data     = data.template_file.opennms.rendered

  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.common.id,
    aws_security_group.opennms.id,
  ]

  tags = {
    Name        = "Terraform OpenNMS Core Server"
    Environment = "Test"
    Department  = "Support"
  }
}

output "opennms" {
  value = aws_instance.opennms.public_ip
}

