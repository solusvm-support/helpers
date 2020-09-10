#!/bin/bash

# This is script to upgrade SolusVM node to svmstack - svmstack-nginx and PHP 5.6.30
# kb article 360022824452
set -uo pipefail

function menu() {
    clear
    echo " o----------------------------------------------------------------o";
    echo " |                                                                |";
    echo " |            Is the current server Master or Slave node?         |";
    echo " |                                                                |";
    echo " |                                                                |";
    echo " |   ----------------------------------------------------------   |";
    echo " |   | Type            |                Option                    |";
    echo " |   ==========================================================   |";
    echo " |   | SolusVM Master  |                  [1]                     |";
    echo " |   ----------------------------------------------------------   |";
    echo " |   | SolusVM Slave   |                  [2]                     |";
    echo " |   ----------------------------------------------------------   |";
    echo " |                                                                |";
    echo " o----------------------------------------------------------------o";
    echo ""
    echo " Choose an option : ";

    read -r option;
	  until [ "${option}" == "1" ] || [ "${option}" == "2" ]; do
        echo "   Please enter a valid option: ";
        read -r option;
        done
        if [ "${option}" == "1" ]; then
            upgradeMaster;
        elif [ "${option}" == "2" ]; then
            upgradeSlave;
        fi
}

function upgradeMaster () {

  echo "Stopping and disabling lighttpd..."
  service lighttpd stop
  chkconfig lighttpd off

  echo "Installing the latest solusvm-release..."
  yum install solusvm-release -y
  echo "Updating PHP..."
  yum update svmstack-php -y
  mv /usr/bin/php /usr/bin/backup-php
  ln -s /usr/local/svmstack/php/bin/php /usr/bin/php

  echo "Installing svmstack-nginx..."
  yum install svmstack-nginx svmstack-nginx-legacy-master-config -y

  echo "Starting services..."

  chkconfig svmstack-nginx on
  chkconfig svmstack-fpm on
  service svmstack-nginx restart
  service svmstack-fpm restart

  echo "Upgrade to svmstack-nginx and PHP 5.6.30 is completed!"
}

function upgradeSlave () {

  echo "Stopping and disabling lighttpd..."

  service lighttpd stop
  chkconfig lighttpd off

  echo "Installing the latest solusvm-release..."
  yum install solusvm-release -y

  echo "Updating PHP..."
  yum update svmstack-php -y
  mv /usr/bin/php /usr/bin/backup-php
  ln -s /usr/local/svmstack/php/bin/php /usr/bin/php

  echo "Installing svmstack-nginx..."
  yum install svmstack-nginx svmstack-nginx-legacy-slave-config -y

  echo "Starting services..."
  chkconfig svmstack-nginx on
  chkconfig svmstack-fpm on

  service svmstack-nginx restart
  service svmstack-fpm restart

  echo "Upgrade to svmstack-nginx and PHP 5.6.30 is completed!"
}

function main () {

  menu
}

main "$@"
