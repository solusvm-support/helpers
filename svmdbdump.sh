#! /bin/bash

echo "Backup of SolusVM database started ... "

MYSQL_PWD=`cat /usr/local/solusvm/includes/solusvm.conf | awk -F ":" '{print $3}'` mysqldump -u`cat /usr/local/solusvm/includes/solusvm.conf | awk -F ":" '{print $2}'` `cat /usr/local/solusvm/includes/solusvm.conf | awk -F ":" '{print $1}'` > /root/solusvmdb`date +%F_%H.%M`.sql

echo "Backup has been created and put into /root/ directory"
ls -l /root/ | grep solusvmdb
