#!/bin/bash

if [ $EUID -ne 0 ]; then 
	echo 'Run this script under root'
	exit 1;
fi

case "$1" in
        --help|help|-h)
                echo "";
                echo "Usage: $0 add/remove";
                echo "";
                exit 0;
                ;;
esac

KEY=''
flag=$1;
if [ "$flag" == 'add' ]; then
	mkdir -p ~/.ssh
	chmod 700 ~/.ssh
	touch ~/.ssh/authorized_keys
	IS_EXIST=$(cat ~/.ssh/authorized_keys | grep -w support@solusvm.com)
	if [ "${IS_EXIST}" == "" ]; then
		echo "Downloading SSH key..."
		wget https://support.solus.io/hc/en-us/article_attachments/360013515211/id_rsa.pub -O /tmp/support-rsa-key >/dev/null 2>&1
		echo "Downloading SHA Checksum..."
		wget https://support.solus.io/hc/en-us/article_attachments/360014184691/id_rsa.checksum -O /tmp/support-rsa-key-checksum >/dev/null 2>&1
		CHECKSUM=$(cat /tmp/support-rsa-key-checksum | awk '{ print $1 }')
		KEYSUM=$(md5sum /tmp/support-rsa-key | awk '{ print $1 }')
		if [ "${CHECKSUM}" == "${KEYSUM}" ]; then
			KEY=$(cat /tmp/support-rsa-key)
			echo "${KEY}" >> ~/.ssh/authorized_keys
			rm -f /tmp/support-rsa-key
			rm -f /tmp/support-rsa-key-checksum
			echo "Key installed"
		else
			echo "Could not install Key. Checksum failed."
		fi
	else
		echo "Key is already installed"
	fi
	chmod 600 ~/.ssh/authorized_keys

	elif [ "$flag" == 'remove' ]; then
		IS_EXIST=$(cat ~/.ssh/authorized_keys | grep -w support@solusvm.com)
		if [ "${IS_EXIST}" == "" ]; then
			echo "Key not found"
		else
			sed -i '/support@solusvm.com/ d' ~/.ssh/authorized_keys
			echo "Key removed"
		fi
	else
		echo "Usage: $0 add/remove"
fi
