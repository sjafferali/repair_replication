#!/bin/bash

REMOTE_HOST=$1
ID=$(($(uname -n | awk -F'.' '{print$1}' |  egrep -o [0-9])+1))
R_USER=$2
R_PASS=$3

if [[ -z $R_PASS ]]
then
	echo "Usage: $0 [master_host] [replication_user] [replication_password]"
	exit 1
fi

yum install http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm -y
yum install percona-xtrabackup -y
ssh -p 2222 root@$REMOTE_HOST "yum install http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm -y"
ssh -p 2222 root@$REMOTE_HOST "yum install percona-xtrabackup -y"

systemctl stop mysqld.service
rm -rf /var/lib/mysql/*
sed -i "s/server-id.*/server-id = $ID/" /etc/my.cnf

ssh -p 2222 root@$REMOTE_HOST "innobackupex --stream=tar /tmp/ --slave-info | gzip -" | gunzip - | tar xfi - -C /var/lib/mysql
innobackupex --apply-log /var/lib/mysql/
chown mysql:mysql /var/lib/mysql -R

BINLOG=$(cat /var/lib/mysql/xtrabackup_binlog_info | awk '{print$1}')
POS=$(cat /var/lib/mysql/xtrabackup_binlog_info | awk '{print$2}')

mysql -e "CHANGE MASTER TO MASTER_HOST='${REMOTE_HOST}', MASTER_USER='${R_USER}', MASTER_PASSWORD='${R_PASS}', MASTER_LOG_FILE='${BINLOG}', MASTER_LOG_POS='${POS}'"
mysql -e "start slave"
