#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

# AWS Template Variables - Start

node_id="${node_id}"
num_partitions="${num_partitions}"
replication_factor="${replication_factor}"
min_insync_replicas="${min_insync_replicas}"
ip_addresses="${ip_addresses}"

# AWS Template Variables - End

echo "### Basic Settings..."

iplist=$(echo $ip_addresses | tr "," "\n")
hostname="kafka$node_id"
ip_address=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null)
hostnamectl set-hostname --static $hostname
timedatectl set-timezone "America/New_York"
echo "* - nofile 200000" > /etc/security/limits.d/application.conf

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
mem_in_mb=$(expr $total_mem_in_mb / 2)
if [ "$mem_in_mb" -gt "8192" ]; then
  mem_in_mb="8192"
fi

systemd_kafka=/etc/systemd/system/kafka.service
cat <<EOF > $systemd_kafka
[Unit]
Description=Apache Kafka Server
Documentation=http://kafka.apache.org
Wants=network-online.target
After=network-online.target
[Service]
Type=simple
User=root
Group=root
Environment="KAFKA_HEAP_OPTS=-Xmx$${mem_in_mb}m -Xms$${mem_in_mb}m"
Environment="KAFKA_JMX_OPTS=-Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.rmi.port=9999 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=%H -Djava.net.preferIPv4Stack=true"
Environment="JMX_PORT=9999"
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
[Install]
WantedBy=multi-user.target
EOF
chmod 0644 $systemd_kafka

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
Environment="KAFKA_HEAP_OPTS=-Xmx$${mem_in_mb}m -Xms$${mem_in_mb}m"
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

sed -i -r "s|dataDir=.*|dataDir=$zoo_data|" $zoo_cfg

cat <<EOF >> $zoo_cfg
# Additional Settings
tickTime=10000
initLimit=10
syncLimit=5
EOF
index=1
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

total_mem_in_mb=$(free -m | awk '/:/ {print $2;exit}')
mem_in_mb=$(expr $total_mem_in_mb / 2)
if [ "$mem_in_mb" -gt "4096" ]; then
  mem_in_mb="4096"
fi
sed -i -r "/KAFKA_HEAP_OPTS/s/1g/$${mem_in_mb}m/g" /etc/systemd/system/zookeeper.service

echo "### Enabling and starting Zookeeper..."

systemctl enable zookeeper
systemctl start zookeeper


echo "### Configuring Kafka..."

kafka_cfg=/opt/kafka/config/server.properties
kafka_data=/data/kafka
mkdir -p $kafka_data

zookeeper_connect=""
for ip in $iplist
do
  zookeeper_connect="$zookeeper_connect,$ip:2181"
done
sed -i -r "/^broker.id/s/0/$node_id/" $kafka_cfg
sed -i -r "/^num.partitions/s/1/$num_partitions/" $kafka_cfg
sed -i -r "s|^[#]?listeners=.*|listeners=PLAINTEXT://:9092|" $kafka_cfg
sed -i -r "s|^[#]?advertised.listeners=.*|advertised.listeners=PLAINTEXT://$ip_address:9092|" $kafka_cfg
sed -i -r "s|^log.dirs=.*|log.dirs=$kafka_data|" $kafka_cfg
sed -i -r "s|^zookeeper.connect=.*|zookeeper.connect=$zookeeper_connect|" $kafka_cfg

cat <<EOF >> $kafka_cfg
default.replication.factor=$replication_factor
min.insync.replicas=$min_insync_replicas
controlled.shutdown.enable=true
auto.create.topics.enable=true
delete.topic.enable=false
EOF

password_file=/usr/java/latest/jre/lib/management/jmxremote.password
cat <<EOF > $password_file
monitorRole QED
controlRole R&D
kafka kafka
EOF
chmod 400 $password_file

systemctl --now enable zookeeper
systemctl --now enable kafka