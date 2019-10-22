#!/usr/bin/env bash

awk -F: '{ system("MYSQL_PWD='"'"'" $3 "'"'"' mysql -u " $2 " "$1) }' /usr/local/solusvm/includes/solusvm.conf
