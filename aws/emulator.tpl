#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

set -e

echo "### Basic Settings..."

hostname="emulator"
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
yum install -y jq wget unzip net-snmp net-snmp-utils dstat htop sysstat nmap-ncat screen vim golang git

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

echo "### Installing and Configuring Emulator..."

export GOPATH=/tmp/go
export GOCACHE=/tmp/go
mkdir -p $GOPATH
cd /tmp
git clone https://github.com/agalue/onms-minion-emulator.git
cd onms-minion-emulator
go build
cp onms-minion-emulator /usr/local/bin
