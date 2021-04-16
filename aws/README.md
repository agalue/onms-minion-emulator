# Minion Emulator lab in AWS

This would start a production grade Kafka cluster and OpenNMS server to perform stress tests with thousands of Minions

## Installation

* Make sure you have your AWS credentials on `~/.aws/credentials`, for example:

```INI
[default]
aws_access_key_id = XXXXXXXXXXXXXXXXX
aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

* Install the Terraform binary from [terraform.io](https://www.terraform.io)

* Tweak the common settings on [vars.tf](./vars.tf), and please do not change the other `.tf` files.

    * Update `aws_key_name` and `aws_private_key`, to match the chosen region.

    * Make sure the number of partitions for Kafka is greater than the total number of Minions you're expecting to have.

* Execute the following commands from the repository's root directory (at the same level as the .tf files):

```SHELL
terraform init
terraform plan
terraform apply
```

## Usage

SSH the emulator VM, and then execute the software, for instance:

```bash=
onms-minion-emulator -l warn -n 1000 -t kafka -u 172.16.1.11:9092
```

Make sure that the IP address of the broker matches what's defined in [vars.tf](./vars.tf).