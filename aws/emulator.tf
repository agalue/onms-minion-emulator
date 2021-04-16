# @author: Alejandro Galue <agalue@opennms.org>

data "template_file" "emulator" {
  template = file("emulator.tpl")
}

resource "aws_instance" "emulator" {
  ami           = data.aws_ami.amazon_linux_2.image_id
  instance_type = var.instance_types.emulator
  subnet_id     = aws_subnet.public.id
  key_name      = var.aws_key_name
  private_ip    = var.emulator_ip_address
  user_data     = data.template_file.emulator.rendered

  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.common.id,
  ]

  tags = {
    Name        = "Terraform Minion Emulator"
    Environment = "Test"
    Department  = "Support"
  }
}

output "emulator" {
  value = aws_instance.emulator.public_ip
}

