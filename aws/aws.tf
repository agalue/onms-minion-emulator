# @author: Alejandro Galue <agalue@opennms.org>

############################ IMPORTANT ############################
#
# Make sure you put your AWS credentials on ~/.aws/credentials
# prior start using this recipe.
#
###################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = var.aws_region
}

data "aws_ami" "amazon_linux_2" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

