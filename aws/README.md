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

* Execute the following commands from the repository's root directory (at the same level as the .tf files):

```SHELL
terraform init
terraform plan
terraform apply
```

## Usage

SSH the emulator VM, and then execute the software, for instance:

```bash=
onms-minion-emulator -l warn -n 1000 -m 2 -t kafka -u 172.16.1.11:9092
```

Make sure that the IP address of the broker matches what's defined in [vars.tf](./vars.tf).

The above creates 2000 Minions (1000 Locations, with 2 Minions on each of them).

**WARNING: Watch out for the file descriptors. I recommend reading [this](https://www.confluent.io/blog/how-choose-number-topics-partitions-kafka-cluster/) article. In essence, try to reduce the number of partitions per topic as much as you can. Remember that even with single-topic enabled for RPC, there would be one `rpc-request` topic per location.