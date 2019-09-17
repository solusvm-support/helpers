#! /bin/bash
MYSQL_PWD=`cat /usr/local/solusvm/includes/solusvm.conf | awk -F ":" '{print $3}'` mysql `cat /usr/local/solusvm/includes/solusvm.conf | awk -F ":" '{print $1}'` -u`cat /usr/local/solusvm/includes/solusvm.conf | awk -F ":" '{print $2}'`
