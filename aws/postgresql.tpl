#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

set -e

# AWS Template Variables - Start

vpc_cidr="${vpc_cidr}"

# AWS Template Variables - End

echo "### Basic Settings..."

hostname="database"
ip_address=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null)
hostnamectl set-hostname --static $hostname
timedatectl set-timezone "America/New_York"

echo "### Kernel Tuning..."

echo "* - nofile 1000000" > /etc/security/limits.d/application.conf

cat <<EOF > /etc/sysctl.d/application.conf
# Disable TCP timestamps to improve CPU utilization (optional):
net.ipv4.tcp_timestamps=0

# Enable TCP sacks to improve throughput:
net.ipv4.tcp_sack=1

# Increase the maximum length of processor input queues:
net.core.netdev_max_backlog=250000

# Increase the TCP max and default buffer sizes using setsockopt():
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.core.rmem_default=4194304
net.core_wmem_default=4194304
net.core.optmem_max=4194304

# Increase memory thresholds to prevent packet dropping:
net.ipv4.tcp_rmem="4096 87380 4194304"
net.ipv4.tcp_wmem="4096 65536 4194304"

# Enable low latency mode for TCP:
net.ipv4.tcp_low_latency=1

# Set the socket buffer to be divided evenly between TCP window size and application buffer:
net.ipv4.tcp_adv_win_scale=1

# Disable Swap
vm.swappiness=1
vm.zone_reclaim_mode=0
vm.max_map_count=1048575
EOF
sysctl -p /etc/sysctl.d/application.conf

echo "### Installing common packages..."

amazon-linux-extras install epel -y
yum install -y jq wget unzip net-snmp net-snmp-utils dstat htop sysstat nmap-ncat screen vim haveged

echo "### Configuring SNMP..."

snmp_cfg=/etc/snmp/snmpd.conf
cat <<EOF > $snmp_cfg
rocommunity public default
syslocation AWS
syscontact Account Manager
dontLogTCPWrappersConnects yes
disk /
EOF
chmod 600 $snmp_cfg
systemctl --now enable snmpd

echo "### Installing and Configuring PostgreSQL..."

amazon-linux-extras install postgresql10 -y
yum install -y yum install postgresql-server
/usr/bin/postgresql-setup --initdb --unit postgresql
sed -r -i "/^(local|host)/s/(peer|ident)/trust/g" /var/lib/pgsql/data/pg_hba.conf
sed -r -i "s|127.0.0.1/32|$vpc_cidr|g" /var/lib/pgsql/data/pg_hba.conf

num_of_cores=$(cat /proc/cpuinfo | grep "^processor" | wc -l)
total_mem_in_mb=$(free -m | awk '/:/ {print $2;exit}')

let shared_buffers="$total_mem_in_mb / 4"
let effective_cache_size="$total_mem_in_mb * 3/4"
let work_mem="327 * $total_mem_in_mb / 1024"

cat <<EOF >> /var/lib/pgsql/data/postgresql.conf
# https://pgtune.leopard.in.ua/#/
# DB Version: 10
# OS Type: linux
# DB Type: mixed
# Total Memory (RAM): $total_mem_in_mb MB
# CPUs num: $num_of_cores
# Connections num: 100
# Data Storage: ssd

max_connections = 100
shared_buffers = $${shared_buffers}MB
effective_cache_size = $${effective_cache_size}MB
maintenance_work_mem = 2GB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = $${work_mem}kB
min_wal_size = 1GB
max_wal_size = 4GB
max_worker_processes = $num_of_cores
max_parallel_workers_per_gather = 4
max_parallel_workers = $num_of_cores
EOF

systemctl --now enable postgresql
