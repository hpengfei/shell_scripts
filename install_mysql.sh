#!/bin/bash

MYSQL_BASEDIR=/usr/local/mysql
MySQL_DATADIR=/data/mysql
SERVER_ID=`hostname -I |awk -F'[. ]' '{print $4}'`

cat >/etc/my.cnf<<EOF   
[mysqld]
datadir=/data/mysql
port=3306
socket=/tmp/mysql.sock
pid-file=/data/mysql/mysqld.pid
user=mysql
skip-name-resolve
server-id=${SERVER_ID}
character_set_server=utf8
gtid_mode=on
enforce_gtid_consistency=1
binlog_format=ROW

## log
log-bin=mysql-bin
log-bin-index=mysql-bin.index
relay-log=mysql-relay-bin
relay-log-index=mysql-relay-bin.index
log_error=error.log
log-slave-updates=1
#skip_slave_start=1

[mysql]
prompt=(\\u@\\h) [\\d]>\\_

[client]
user=root
password=
EOF

COUNT=`ls . |grep mysql-.*-linux-glibc2.5-x86_64.tar.gz |wc -l`
if [ $COUNT -ne 1 ];then
        echo "MySQL install tar file must equal one.This is directory equal $COUNT."
        exit 100
else
        MYSQL_VERSION=`ls . |grep mysql-.*-linux-glibc2.5-x86_64.tar.gz|awk -F'-' '{print $2}'`
fi

MYSQL_FILE_NAME=mysql-${MYSQL_VERSION}-linux-glibc2.5-x86_64.tar.gz

function mysql_install () {
    if [[ `rpm -qa libaio |wc -l` -ne 1 ]]; then
        yum install libaio autoconf || echo "install libaio error."
        exit
    fi

    id mysql >/dev/null 2>&1|| groupadd -r mysql 
    id mysql >/dev/null 2>&1|| useradd -r -g mysql -s /sbin/nologin -M mysql
    if [ ! -d /usr/local/mysql-${MYSQL_VERSION}-linux-glibc2.5-x86_64 ];then
        tar xf ${MYSQL_FILE_NAME} -C /usr/local/ && echo "mysql unzip ok."
    fi

    if [ -L /usr/local/mysql ];then
        unlink /usr/local/mysql
    fi
    ln -sv /usr/local/mysql-${MYSQL_VERSION}-linux-glibc2.5-x86_64 /usr/local/mysql
    echo "export PATH=$PATH:/usr/local/mysql/bin" >/etc/profile.d/mysql.sh
    source /etc/profile.d/mysql.sh
    /bin/cp ${MYSQL_BASEDIR}/support-files/mysql.server /etc/init.d/mysqld
    mkdir -p ${MySQL_DATADIR}
    chown -R mysql.mysql ${MySQL_DATADIR}
}

MYSQL_VERSION_2=`ls . |grep mysql-.*-linux-glibc2.5-x86_64.tar.gz|awk -F'-' '{print $2}' |cut -d'.' -f1-2`
case $MYSQL_VERSION_2 in
    5.7 )
    mysql_install && mysqld --initialize --user=mysql 
    MYSQL_PASSWORD=`grep "root@localhost:" /data/mysql/error.log |awk '{print $NF}'`
    sed -i s/password=/password=$MYSQL_PASSWORD/ /etc/my.cnf
        ;;
    * )
    mysql_install && /usr/local/mysql/scripts/mysql_install_db --user=mysql --basedir=${MYSQL_BASEDIR}
        ;;
esac
source /etc/profile.d/mysql.sh
/etc/init.d/mysqld start && echo 'Please execute command "source /etc/profile.d/mysql.sh"'