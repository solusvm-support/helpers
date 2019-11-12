#!/bin/bash

# This is powerdns interactive installer script
# kb article 360024833972
set -uo pipefail

SLAVE_CONF='/root/master.txt'
INSTALL_LOG='/root/powerdnsinstall.log'

# Here we checking the requirenments
function precheck () {

    echo " ** Please wait while the installer is checking the requirenments...";
    mariadb_check=$(rpm -qa | grep mariadb)
    pdns_check=$(rpm -qa | grep pdns)
	centos_check=$(cat /etc/*release | grep 'CentOS Linux 7')
	
    if [[ "$mariadb_check" == "" ]]; then
        err "Not all pre-requirenments are met, please check that mariadb is installed"
    fi
    
	if [[ "$pdns_check" == "" ]]; then
        err "Not all pre-requirenments are met, please check that pdns is installed"
    fi
	
	if [[ "$centos_check" == "" ]]; then
		err "Wrong OS, this script is designed for CentOS 7 only!"
	fi
	
	clear
	echo "Everything seemed to be fine so far. Proceeding further in a moment..."

	sleep 1
}

function menu() {
    clear
    echo " o----------------------------------------------------------------o";
    echo " |                                                                |";
    echo " |   What PowerDNS type would you would like to install?          |";
    echo " |                                                                |";
    echo " |                                                                |";
    echo " |   ----------------------------------------------------------   |";
    echo " |   | Type            |                Option                    |";
    echo " |   ==========================================================   |";
    echo " |   | PowerDNS Master |                  [1]                     |";
    echo " |   ----------------------------------------------------------   |";
    echo " |   | PowerDNS Slave  |                  [2]                     |";
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
            configureMaster;
        elif [ "${option}" == "2" ]; then
            configureSlave;
        fi
}


function err() {
    echo -e "$*" >&2
    exit 1
}

function configureMaster () {
	echo "Master configuration will be initialized in a moment..."
	sleep 1
	clear
    printf "In order to configure PowerDNS with MariaDB, root password for MariaDB is required.\n\nIf this is a fresh install, press 1 and type the desired password, this script will set it\n\nIf you already have root mysql password, press 2 and enter this password\n\n"
	echo "Choose an option : "
	
	read -r option
	until [[ "$option" == "1" ]] || [[ "$option" == "2" ]]; do
		echo "Please enter a valid option: "
		read -r option
	done
	if [[ "$option" == "1" ]]; then
		setMariadbPassword
	elif [[ "$option" == "2" ]]; then
		checkMariadbPassword
	fi
	
	echo "Now, when password is in place, provide the IP address of SolusVM Master node : "
	read -r SVM_IP_ADDRESS
	ipcalc -cs "$SVM_IP_ADDRESS"
	ipcheck="$?"
	until [[ "$ipcheck" == "0" ]]; do 
		echo "This is not a valid IP, please paste a valid one/"
		echo "Provide the IP address of SolusVM Master node : "
		read -r SVM_IP_ADDRESS
		ipcalc -cs "$SVM_IP_ADDRESS"
		ipcheck="$?"
	done
	
	echo "Fantastic! Now provide the IP Address of future slave : "
	read -r SLAVE_IP_ADDRESS
	ipcalc -cs "$SLAVE_IP_ADDRESS"
	ipcheck="$?"
	until [[ "$ipcheck" == "0" ]]; do 
		echo "This is not a valid IP, please paste a valid one."
		echo "Provide the IP Address of future slave : "
		read -r SLAVE_IP_ADDRESS
		ipcalc -cs "$SLAVE_IP_ADDRESS"
		ipcheck="$?"
	done
	
	echo "Brilliant! Proceeding further..."
	sleep 1
	
	echo "Downloading database schema for PowerDNS..."
	MYSQL_PWD="${sqlpassword}" /usr/bin/mysql -uroot --execute "create database powerdns;"
	curl -o pdns.sql https://support.solusvm.com/hc/en-us/article_attachments/360023860952/pdns.sql &>> "$INSTALL_LOG"
	MYSQL_PWD="${sqlpassword}" /usr/bin/mysql -uroot powerdns < pdns.sql
	rm -f pdns.sql
	
	echo "Adjusting /etc/pdns/pdns.conf file... Backup is at /etc/pdns/pdns.conf.bkp"
	cp -a /etc/pdns/pdns.conf{,.bkp}
	sed -i "s/launch=bind/#launch=bind\nlaunch=gmysql\ngmysql-host=127.0.0.1\ngmysql-user=root\ngmysql-password=${sqlpassword}\ngmysql-dbname=powerdns/g" /etc/pdns/pdns.conf
	sleep 1
	
	echo "Adjusting /etc/my.cnf file... Backup is at /etc/my.cnf.bkp"
	cp -a /etc/my.cnf{,.bkp}
	sed -i '/\mysqld_safe/i\server-id = 1\nlog-bin = mysql-bin\n\log-bin-index = mysql-bin.index\nexpire-logs-days = 10\nmax-binlog-size = 100M\nbinlog-do-db = powerdns\nbinlog_format=ROW\nbind-address=0.0.0.0' /etc/my.cnf
	sleep 1
	
	echo "Restarting services..."
	service pdns restart &>> "$INSTALL_LOG" 
	pcheck="$?"
	if [[ "$pcheck" != "0" ]]; then
		err "Something went wrong while restarting pdns, contact support"
	fi
	
	service mariadb restart &>> "$INSTALL_LOG" 
	mcheck="$?"
	if [[ "$mcheck" != "0" ]]; then
		err "Something went wrong while restarting mariadb, contact support"
	fi
	
	echo "Creating user for SolusVM master..."
	svmpassword=$(openssl rand -base64 14)
	MYSQL_PWD="${sqlpassword}" /usr/bin/mysql -uroot --execute "create user 'pdnsslave'@'%' identified by '$svmpassword'; grant replication slave on *.* to 'pdnsslave'@'%' identified by '$svmpassword'; grant all on powerdns.* to 'root'@'$SVM_IP_ADDRESS' identified by '$sqlpassword'; flush privileges;"
	
	sleep 1
	
	echo "Adjusting firewall rules..."
	iptables -A INPUT -s "$SVM_IP_ADDRESS"/32 -j ACCEPT
	iptables -A INPUT -s "$SLAVE_IP_ADDRESS"/32 -j ACCEPT
	
	printf "\n\n\n"
	echo "-----------------------------------------------------"
	printf "Everything is done. Please take the information between '*********' and save it into %s file on slave server.\n" "$SLAVE_CONF"
	MYSQL_PWD="${sqlpassword}" /usr/bin/mysql -uroot --execute "use powerdns; show master status \G" > $SLAVE_CONF
	echo "svmpassword: $svmpassword" >> $SLAVE_CONF
	cat $SLAVE_CONF
	printf "*************************** 1. row ***************************\n"
	
	echo "Use the following information to connect PowerDNS Master server to SolusVM node : "
	printf "\n IP Address: $(hostname -I |  sed  's/127.0.0.1 //g') \n SQL Port: 3306 \n SQL Username: root \n SQL Password: %s \n SQL Database: powerdns \n" "$sqlpassword"
}

function slaveprerequrenments() {
	[[ ! -r $SLAVE_CONF ]] && err "Cannot find $SLAVE_CONF file or cannot read it.\nDo not forget to take it from already installed PowerDNS master."
	
	count=$(grep -cE 'File|Position|Binlog_Do_DB|Binlog_Ignore_DB|svmpassword' $SLAVE_CONF)
	[[ "$count" != 5 ]] && err "Error! File $SLAVE_CONF is having incorrect format. Exiting now..."
	
	FILE=$(grep 'File:' master.txt | cut -d ':' -f 2 | tr -d " ")
	POSITION=$(grep 'Position:' master.txt | cut -d ':' -f 2 | tr -d " ")
	SVMPASS=$(grep 'svmpassword:' master.txt | cut -d ':' -f 2 | tr -d " ")
	
	echo "Looks good! Proceeding further..."
}

function configureSlave () {
	
	echo "Checking whether or not everything is fine with $SLAVE_CONF..."
	sleep 1
	
	slaveprerequrenments
	
	echo "Slave configuration will be initialized in a moment..."
	sleep 1
	clear
    printf "In order to configure PowerDNS with MariaDB, root password for MariaDB is required.\n\nIf this is a fresh install, press 1 and type the desired password, this script will set it.\n\nIf you already have root mysql password, press 2 and enter this password.\n\n"
	echo "Choose an option : "
	read -r option
	until [[ "$option" == "1" ]] || [[ "$option" == "2" ]]; do
		echo "Please enter a valid option: "
		read -r option
	done
	if [[ "$option" == "1" ]]; then
		setMariadbPassword
	elif [[ "$option" == "2" ]]; then
		checkMariadbPassword
	fi
	
	echo "Now, when password is in place, provide the IP address of PowerDNS Master server : "
	read -r MASTER_IP_ADDRESS
	ipcalc -cs "$MASTER_IP_ADDRESS"
	ipcheck="$?"
	until [[ "$ipcheck" == "0" ]]; do 
		echo "This is not a valid IP, please paste a valid one."
		echo "Provide the IP address of PowerDNS Master server : "
		read -r MASTER_IP_ADDRESS
		ipcalc -cs "$MASTER_IP_ADDRESS"
		ipcheck="$?"
	done
	
	echo "Fantastic! Proceeding further..."
	sleep 1
	
	echo "Downloading database schema for PowerDNS..."
	MYSQL_PWD="${sqlpassword}" /usr/bin/mysql -uroot --execute "create database powerdns;"
	curl -o pdns.sql https://support.solusvm.com/hc/en-us/article_attachments/360023860952/pdns.sql &>> "$INSTALL_LOG"
	MYSQL_PWD="${sqlpassword}" /usr/bin/mysql -uroot powerdns < pdns.sql
	rm -f pdsn.sql
	
	echo "Adjusting /etc/pdns/pdns.conf file... Backup is at /etc/pdns/pdns.conf.bkp"
	cp -a /etc/pdns/pdns.conf{,.bkp}
	sed -i "s/launch=bind/#launch=bind\nlaunch=gmysql\ngmysql-host=127.0.0.1\ngmysql-user=root\ngmysql-password=${sqlpassword}\ngmysql-dbname=powerdns/g" /etc/pdns/pdns.conf
	sleep 1
	
	echo "Adjusting /etc/my.cnf file... Backup is at /etc/my.cnf.bkp"
	cp -a /etc/my.cnf{,.bkp}
	sed -i '/\mysqld_safe/i\server-id = 2\nrelay-log=slave-relay-bin\nrelay-log-index=slave-relay-bin.index\nreplicate-do-db=powerdns' /etc/my.cnf
	sleep 1
	
	echo "Restarting services..."
	service pdns restart &>> "$INSTALL_LOG" 
	pcheck="$?"
	if [[ "$pcheck" != "0" ]]; then
		err "Something went wrong while restarting pdns, contact support"
	fi
	
	service mariadb restart &>> "$INSTALL_LOG"
	mcheck="$?"
	if [[ "$mcheck" != "0" ]]; then
		err "Something went wrong while restarting mariadb, contact support"
	fi
	
	echo "Adjusting firewall rules..."
	iptables -A INPUT -s "$MASTER_IP_ADDRESS"/32 -j ACCEPT
	sleep 1
	
	echo "Configuring Slave server to replicate the database..."
	
	MYSQL_PWD="${sqlpassword}" /usr/bin/mysql -uroot --execute "change master to master_host='$MASTER_IP_ADDRESS',master_user='pdnsslave',master_connect_retry=60,master_password='$SVMPASS',master_log_file='$FILE',master_log_pos=$POSITION; start slave"
	
	echo "Checking whether or not status is fine..."
	sleep 2
	
	STATUS_CHECK=$(MYSQL_PWD="${sqlpassword}" /usr/bin/mysql -uroot --execute "show slave status \G" | grep 'Last_IO_Error' | grep -i 'code')
	
	if [[ "$STATUS_CHECK" != "" ]]; then
	
		MYSQL_PWD="${sqlpassword}" /usr/bin/mysql -uroot --execute "show slave status \G" | grep 'Last_IO_Error'
		err "Something went wrong, inspect the output above in order to find the reason and fix it manually"
	fi
	
	printf "\n\n\nOutstanding! The setup is finished. Enjoy your PowerDNS and add it to SolusVM as described at https://docs.solusvm.com/display/BET/Adding+the+PowerDNS+master+to+SolusVM\n"
	rm -f /root/master.txt
	
}

function setMariadbPassword() {
	echo "Enter desired root password for MariaDB : "
	read -r -s sqlpassword
	echo "Enter the password again : "
	read -r -s sqlpassword2
	until [[ "$sqlpassword" == "$sqlpassword2" ]]; do
		echo "Passwords do not match. Try again/"
		echo "Enter desired root password for MariaDB : "
		read -r -s sqlpassword
		echo "Enter the password again : "
		read -r -s sqlpassword2
	done
	
	/usr/bin/mysqladmin -u root password "${sqlpassword}"
	check_connect="$?"
	if [[ "$check_connect" == "0" ]]; then
		echo "Password is set correctly"
	else
		err "something went wrong, please contact support"
	fi
	
	# let's also remove accessing mysql from localhost with any user without password
	MYSQL_PWD="${sqlpassword}" /usr/bin/mysql -uroot --execute "drop user ''@'localhost'; flush privileges"
	
	
}

function checkMariadbPassword() {
	echo "Enter current root password for Mariadb"
	read -r -s sqlpassword
	MYSQL_PWD="$sqlpassword" mysql -uroot --execute "show databases" > /dev/null 2>&1
	check_connect="$?"
	until [[ "$check_connect" == "0" ]]; do
		echo "Cannot connect to local mysql server as root user with the provided password."
		echo "Enter current root password for Mariadb (tip: in case you selected the wrong option and do not have root mysql password, press 1 : "
				read -r -s sqlpassword
		if [[ "$sqlpassword" == "1" ]]; then
			printf "Alright, going back to option 1... \n"
			setMariadbPassword
			return
		fi
		MYSQL_PWD="${sqlpassword}" /usr/bin/mysql -uroot --execute "show databases" > /dev/null 2>&1
		check_connect="$?"
	done
}


function cleanup () {

	[[ -f "pdns.sql" ]] && rm -f pdns.sql
	
	if [[ -f "/etc/my.cnf.bkp" ]]; then
		rm -f /etc/my.cnf 
		cp -a /etc/my.cnf.bkp /etc/my.cnf
	fi
	[[ "$(systemctl is-active mariadb)" != "active" ]] && systemctl start mariadb.service
	
	if [[ -f "/etc/pdns/pdns.conf.bkp" ]]; then
		rm -f /etc/pdns.pnds.conf
		cp -a /etc/pnds/pdns.conf.bkp /etc/pdns/pdns.conf
	fi
	[[ "$(systemctl is-active pdns)" != "active" ]] && systemctl start pdns.service
	
	MYSQL_PWD="$sqlpassword" mysql -uroot --execute "show databases" > /dev/null 2>&1
	check_connect="$?"	
	[[ "$check_connect" == "0" ]] && MYSQL_PWD="${sqlpassword}" /usr/bin/mysql -uroot --execute "drop user powerdns; flush privileges;"
	
	MASTER_RULE=$(iptables --line-numbers -L | grep "$MASTER_IP_ADDRESS" | cut -d " " -f 1)
	SLAVE_RULE=$(iptables --line-numbers -L | grep "$SLAVE_RULE_IP_ADDRESS" | cut -d " " -f 1)
	SVM_RULE=$(iptables --line-numbers -L | grep "$SVM_IP_ADDRESS" | cut -d " " -f 1)
	
	[[ -n "$MASTER_RULE" ]] &&  iptables -D INPUT "$MASTER_RULE"
	[[ -n "$SLAVE_RULE" ]] && iptables -D INPUT "$SLAVE_RULE"
	[[ -n "$SVM_RULE" ]] && iptables -D INPUT "$SVM_RULE"
	
}
function main () {

precheck
menu
}

main "$@"
