#!/bin/bash
# The script creates a backup of SolusVM database and puts it into /root/ directory

echo "Backup of SolusVM database started... "
sleep 1

# checking that solusvm.conf exists
if [[ -f /usr/local/solusvm/includes/solusvm.conf ]]; then
    echo -e "\nVerified that file /usr/local/solusvm/includes/solusvm.conf exists. Continue...\n"
else
    echo -e "\n---------------------------------\n"
    echo -e "Backup is failed to create: file /usr/local/solusvm/includes/solusvm.conf does not exists.\n"
    echo -e "Make sure that the server is correct and SolusVM Master software is installed"
    exit 1
fi

set -Eoe pipefail
trap "echo "";echo Something went wrong. Backup failed to create; rm -f /root/4175078534svmdb.tmp" ERR

MYSQL_PWD=`cat /usr/local/solusvm/includes/solusvm.conf | awk -F ":" '{print $3}'`
mysqldump -u`cat /usr/local/solusvm/includes/solusvm.conf | awk -F ":" '{print $2}'` "-p${MYSQL_PWD}" `cat /usr/local/solusvm/includes/solusvm.conf | awk -F ":" '{print $1}'` > /root/4175078534svmdb.tmp

bkp_name=$(echo solusvmdb`date +%F_%H.%M`.sql)
mv /root/4175078534svmdb.tmp /root/$bkp_name

echo "Backup file /root/$bkp_name has been created"
