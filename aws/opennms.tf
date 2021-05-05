# @author: Alejandro Galue <agalue@opennms.org>

data "template_file" "opennms" {
  template = file("opennms.tpl")

  vars = {
    zk_servers                    = "${aws_instance.kafka[0].private_ip}:2181"
    kafka_servers                 = "${aws_instance.kafka[0].private_ip}:9092"
    postgres_ip_address           = aws_instance.postgresql.private_ip
    rpc_ttl                       = var.settings.onms_rpc_ttl
    fd_limit_opennms              = var.settings.fd_limit_opennms
    onms_branch                   = var.settings.onms_branch
    onms_pollerd_threads          = var.settings.onms_pollerd_threads
    onms_collectd_threads         = var.settings.onms_collectd_threads
    onms_provisiond_scan_threads  = var.settings.onms_provisiond_scan_threads
    onms_provisiond_write_threads = var.settings.onms_provisiond_write_threads
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

  root_block_device {
    volume_type = "gp2"
    volume_size = var.settings.onms_disk_space_in_gb
  }

  tags = {
    Name        = "Terraform OpenNMS Server"
    Environment = "Test"
    Department  = "Support"
  }
}

output "opennms" {
  value = aws_instance.opennms.public_ip
}

