#! /bin/bash
MYSQL_PWD=`cat /usr/local/solusvm/includes/solusvm.conf | awk -F ":" '{print $3}'` mysqldump -u`cat /usr/local/solusvm/includes/solusvm.conf | awk -F ":" '{print $2}'` `cat /usr/local/solusvm/includes/solusvm.conf | awk -F ":" '{print $1}'` > /root/solusvm`date +%F_%H.%M`.sql
