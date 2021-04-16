# @author: Alejandro Galue <agalue@opennms.org>

# Region

variable "aws_region" {
  description = "EC2 Region for the VPC"
  default     = "us-west-2" # For testing purposes only (should be changed)
}

# Access (make sure to use your own keys)

variable "aws_key_name" {
  description = "AWS Key Name, to access EC2 instances through SSH"
  default     = "agalue" # For testing purposes only (should be changed, based on aws_region)
}

variable "aws_private_key" {
  description = "AWS Private Key Full Path"
  default     = "/Users/agalue/.ssh/agalue.private.aws.us-east-2.pem" # For testing purposes only (should be changed, based on aws_region)
}

variable "instance_types" {
  description = "Instance types per server/application"
  type        = map

  default = {
    opennms  = "m5.4xlarge"
    kafka    = "m5.4xlarge"
    emulator = "m5.4xlarge"
  }
}

# Networks

variable "vpc_cidr" {
  description = "CIDR for the whole VPC"
  default     = "172.16.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for the public subnet"
  default     = "172.16.1.0/24"
}

# Application IP Addresses

variable "onms_ip_address" {
  description = "OpenNMS IP Address"
  default     = "172.16.1.100"
}

variable "emulator_ip_address" {
  description = "Minion Emulator IP Address"
  default     = "172.16.1.101"
}

# Used to decide the size of the cluster#
variable "kafka_ip_addresses" {
  description = "Kafka Servers IP Addresses"
  type        = list

  default = [
    "172.16.1.11",
    "172.16.1.12",
    "172.16.1.13",
  ]
}

# Application settings

variable "settings" {
  description = "Common application settings"
  type        = map

  default = {
    kafka_disk_space          = 100 # In GB
    kafka_num_partitions      = 1500 # Must be greater than total Minions
    kafka_replication_factor  = 2
    kafka_min_insync_replicas = 1
    onms_rpc_ttl              = 60000 # In milliseconds
  }
}

