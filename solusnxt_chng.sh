#!/usr/bin/env bash
# Fix for the issue caused by changing SOLUS IO installation directory name from solusnxt to solus on CR nodes
# corresponfing KB article 360012560400

set -euo pipefail

function init() {
    echo "Checking that solusnxt directories exist: \n"
    [[ ! -d /etc/solusnxt/ ]] && \
        err "Cannot find /etc/solusnxt/ directory\n" \
            "Make sure that the server is correct and directory exists"
    [[ ! -d /usr/local/solusnxt ]] && \
        err "Cannot find /usr/local/solusnxt/ directory\n" \
            "Make sure that the server is correct and directory exists"
	echo "PASS\n"
}

function move_directories() {
	echo "Copying content from /etc/solusnxt/ to /etc/solus \n"
	cp -r /etc/solusnxt/ /etc/solus
	echo "Completed \n"
	
	echo "Removing cache from /usr/local/solusnxt/cache/ \n"
	rm -rf /usr/local/solusnxt/cache/*
	echo "Completed \n"
	
	echo "Copying content from /usr/local/solusnxt to /usr/local/solus \n"
	cp -r /usr/local/solusnxt /usr/local/solus
	echo "Completed \n"
}

function update_services() {
	echo "Stopping/disabling old solusnxt-agent.service \n"
	systemctl stop solusnxt-agent.service
	systemctl disable solusnxt-agent.service
	rm -f /etc/systemd/system/solusnxt-agent.service
	systemctl mask solusnxt-agent.service
	echo "Completed \n"
	
	echo "Enabling/starting solus-agent.service \n"
	systemctl daemon-reload
}

function main() {
    init
    move_directories
	update_services
}

main "$@"
