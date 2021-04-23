#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

set -e

echo "### Basic Settings..."

hostname="emulator"
ip_address=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null)
hostnamectl set-hostname --static $hostname
timedatectl set-timezone "America/New_York"
echo "* - nofile 1000000" > /etc/security/limits.d/application.conf

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
