#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

# AWS Template Variables - Start

zk_servers="${zk_servers}"
kafka_servers="${kafka_servers}"
rpc_ttl="${rpc_ttl}"

# AWS Template Variables - End

echo "### Basic Settings..."

hostname="opennms"
ip_address=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null)
hostnamectl set-hostname --static $hostname
timedatectl set-timezone "America/New_York"
echo "* - nofile 200000" > /etc/security/limits.d/application.conf

echo "### Installing common packages..."

amazon-linux-extras install epel -y
yum install -y jq wget unzip net-snmp net-snmp-utils dstat htop sysstat nmap-ncat screen vim haveged
amazon-linux-extras install java-openjdk11 -y
yum install -y java-11-openjdk-devel
systemctl --now enable haveged

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
systemctl --now enable postgresql

echo "### Installing OpenNMS..."

sed -r -i '/name=Amazon Linux 2/a exclude=rrdtool-*' /etc/yum.repos.d/amzn2-core.repo
yum install -y http://yum.opennms.org/repofiles/opennms-repo-stable-rhel7.noarch.rpm
rpm --import /etc/yum.repos.d/opennms-repo-stable-rhel7.gpg
yum install -y jicmp jicmp6 jrrd jrrd2 rrdtool 'perl(LWP)' 'perl(XML::Twig)'
yum install -y opennms-core opennms-webapp-jetty opennms-webapp-hawtio opennms-helm

echo "### Configuring OpenNMS..."

opennms_home=/opt/opennms
opennms_etc=$opennms_home/etc

num_of_cores=$(cat /proc/cpuinfo | grep "^processor" | wc -l)
half_of_cores=$(expr $num_of_cores / 2)
total_mem_in_mb=$(free -m | awk '/:/ {print $2;exit}')
mem_in_mb=$(expr $total_mem_in_mb / 2)
if [ "$mem_in_mb" -gt "30720" ]; then
  mem_in_mb="30720"
fi

cat <<EOF > $opennms_etc/opennms.conf
START_TIMEOUT=0
JAVA_HEAP_SIZE=$mem_in_mb
MAXIMUM_FILE_DESCRIPTORS=204800

# Prefer IPv4
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Djava.net.preferIPv4Stack=true"

# To avoid issues with 'opennms status'
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+StartAttachListener"

# GC Logging
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -verbosegc -Xlog:gc* -Xlog:gc:/opt/opennms/logs/gc.log:uptimemillis:filecount=10,filesize=10m"

# GC Settings
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+UseStringDeduplication"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+UseG1GC"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:G1RSetUpdatingPauseTimePercent=5"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:MaxGCPauseMillis=500"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:InitiatingHeapOccupancyPercent=70"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:ParallelGCThreads=$half_of_cores"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:ConcGCThreads=$half_of_cores"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+ParallelRefProcEnabled"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+AlwaysPreTouch"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+UseTLAB"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+ResizeTLAB"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:-UseBiasedLocking"
EOF

sed -r -i '/sshHost/s/127.0.0.1/0.0.0.0/' $opennms_etc/org.apache.karaf.shell.cfg

cat <<EOF > $opennms_etc/opennms.properties.d/kafka.properties
org.opennms.activemq.broker.disable=true
org.opennms.core.ipc.sink.strategy=kafka
org.opennms.core.ipc.sink.kafka.bootstrap.servers=$kafka_servers
org.opennms.core.ipc.rpc.strategy=kafka
org.opennms.core.ipc.rpc.kafka.bootstrap.servers=$kafka_servers
org.opennms.core.ipc.rpc.kafka.ttl=$rpc_ttl
org.opennms.core.ipc.rpc.kafka.single-topic=true
org.opennms.core.ipc.rpc.kafka.auto.offset.reset=latest
EOF

cat <<EOF > $opennms_etc/opennms.properties.d/rrd.properties
org.opennms.rrd.strategyClass=org.opennms.netmgt.rrd.rrdtool.MultithreadedJniRrdStrategy
org.opennms.rrd.interfaceJar=/usr/share/java/jrrd2.jar
opennms.library.jrrd2=/usr/lib64/libjrrd2.so
org.opennms.rrd.storeByGroup=true
org.opennms.rrd.storeByForeignSource=true
EOF

cat <<EOF > $opennms_etc/opennms.properties.d/web.properties
org.opennms.security.disableLoginSuccessEvent=true
org.opennms.web.defaultGraphPeriod=last_2_hour
EOF

echo "### Start OpenNMS..."

$opennms_home/bin/runjava -S /usr/java/latest/bin/java
$opennms_home/bin/install -dis

systemctl --now enable opennms

echo "### Installing and Running CMAK via Docker..."

amazon-linux-extras install docker -y
systemctl --now enable docker
sleep 5
docker run --name cmak --hostname cmak --detach \
  --expose 9000 \
  --restart always \
  --env ZK_HOSTS=$zk_servers \
  hlebalbau/kafka-manager:stable