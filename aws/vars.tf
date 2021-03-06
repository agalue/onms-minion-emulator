# @author: Alejandro Galue <agalue@opennms.org>

# Region

variable "aws_region" {
  description = "EC2 Region for the VPC"
  default     = "us-east-2" # For testing purposes only (should be changed)
}

# Access (make sure to use your own keys)

variable "aws_key_name" {
  description = "AWS Key Name, to access EC2 instances through SSH"
  default     = "agalue" # For testing purposes only (should be changed, based on aws_region)
}

variable "instance_types" {
  description = "Instance types per server/application"
  type        = map

  default = {
    opennms    = "m5.4xlarge"
    postgresql = "m5.2xlarge"
    kafka      = "m5.4xlarge"
    zookeeper  = "m5.2xlarge"
    emulator   = "m5.4xlarge"
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

variable "postgres_ip_address" {
  description = "PostgreSQL IP Address"
  default     = "172.16.1.101"
}

variable "emulator_ip_address" {
  description = "Minion Emulator IP Address"
  default     = "172.16.1.102"
}

# Used to decide the size of the cluster#
variable "zookeeper_ip_addresses" {
  description = "Zookeeper Servers IP Addresses"
  type        = list

  default = [
    "172.16.1.11",
    "172.16.1.12",
    "172.16.1.13",
  ]
}

# Used to decide the size of the cluster#
variable "kafka_ip_addresses" {
  description = "Kafka Servers IP Addresses"
  type        = list

  default = [
    "172.16.1.21",
    "172.16.1.22",
    "172.16.1.23",
    "172.16.1.24",
    "172.16.1.25",
    "172.16.1.26",
    "172.16.1.27",
  ]
}

# Application settings

variable "settings" {
  description = "Common application settings"
  type        = map

  default = {
    kafka_disk_device_name        = "/dev/sdh"
    kafka_disk_space_in_gb        = 100
    kafka_num_partitions          = 3 # Careful, Kafka could die when having 1500+ Minions
    kafka_replication_factor      = 2
    kafka_min_insync_replicas     = 1
    postgres_disk_space_in_gb     = 100
    onms_branch                   = "release-27.x" # Use "stable" (current release) or a branch name like "release-27.x"
    onms_disk_space_in_gb         = 50
    onms_rpc_ttl                  = 60000 # In milliseconds
    onms_pollerd_threads          = 120
    onms_collectd_threads         = 120
    onms_provisiond_scan_threads  = 60
    onms_provisiond_write_threads = 40
    fd_limit_opennms              = 200000  # Less than 1000000
    fd_limit_zookeeper            = 10000   # Less than 1000000
    fd_limit_kafka                = 5000000 # Less than 1000000
  }
}

