# @author: Alejandro Galue <agalue@opennms.org>

data "template_file" "postgresql" {
  template = file("postgresql.tpl")

  vars = {
    vpc_cidr = var.vpc_cidr
  }
}

resource "aws_instance" "postgresql" {
  ami           = data.aws_ami.amazon_linux_2.image_id
  instance_type = var.instance_types.postgresql
  subnet_id     = aws_subnet.public.id
  key_name      = var.aws_key_name
  private_ip    = var.postgres_ip_address
  user_data     = data.template_file.postgresql.rendered

  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.common.id,
    aws_security_group.postgresql.id,
  ]

  root_block_device {
    volume_type = "gp2"
    volume_size = var.settings.postgres_disk_space_in_gb
  }

  tags = {
    Name        = "Terraform PostgreSQL Server"
    Environment = "Test"
    Department  = "Support"
  }
}

output "postgresql" {
  value = aws_instance.postgresql.public_ip
}

