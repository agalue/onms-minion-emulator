#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

set -e

# AWS Template Variables - Start

node_id="${node_id}"
ip_addresses="${ip_addresses}"
fd_limit="${fd_limit}"

# AWS Template Variables - End

echo "### Basic Settings..."

hostname="kafka$node_id"
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
yum install -y jq wget unzip net-snmp net-snmp-utils dstat htop sysstat nmap-ncat screen vim
amazon-linux-extras install java-openjdk11 -y
yum install -y java-11-openjdk-devel

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

echo "### Install Kafka"

cd /opt
wget https://downloads.apache.org/kafka/2.7.0/kafka_2.13-2.7.0.tgz
tar -xvzf kafka_2.13-2.7.0.tgz
ln -s kafka_2.13-2.7.0 kafka
echo 'PATH=/opt/kafka/bin:$PATH'> /etc/profile.d/kafka.sh
cd

echo "### Configuring Systemd..."

total_mem_in_mb=$(free -m | awk '/:/ {print $2;exit}')

zk_mem=$(expr $total_mem_in_mb / 2)
if [ "$zk_mem" -gt "8192" ]; then
  zk_mem="8192"
fi

systemd_zoo=/etc/systemd/system/zookeeper.service
cat <<EOF > $systemd_zoo
[Unit]
Description=Apache Zookeeper server
Documentation=http://zookeeper.apache.org
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
Group=root
LimitNOFILE=$fd_limit
Environment="KAFKA_HEAP_OPTS=-Xmx$${zk_mem}m -Xms$${zk_mem}m"
Environment="KAFKA_JMX_OPTS=-Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.rmi.port=9997 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=%H -Djava.net.preferIPv4Stack=true"
Environment="JMX_PORT=9997"
ExecStart=/opt/kafka/bin/zookeeper-server-start.sh /opt/kafka/config/zookeeper.properties
ExecStop=/opt/kafka/bin/zookeeper-server-stop.sh

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 $systemd_zoo

systemctl daemon-reload

echo "### Configuring Zookeeper..."

zoo_data=/data/zookeeper
mkdir -p $zoo_data
echo $node_id > $zoo_data/myid

zoo_cfg=/opt/kafka/config/zookeeper.properties

sed -i -r "/^admin.enableServer/s/false/true/" $zoo_cfg
sed -i -r "s|dataDir=.*|dataDir=$zoo_data|" $zoo_cfg

cat <<EOF >> $zoo_cfg
# Additional Settings
tickTime=10000
initLimit=10
syncLimit=5
EOF
index=1
iplist=$(echo $ip_addresses | tr "," "\n")
for ip in $iplist
do
  echo "server.$index=$ip:2888:3888;2181" >> $zoo_cfg
  let index++
done

password_file=/usr/java/latest/jre/lib/management/jmxremote.password
cat <<EOF > $password_file
monitorRole QED
controlRole R&D
zookeeper zookeeper
EOF
chmod 400 $password_file

systemctl --now enable zookeeper
