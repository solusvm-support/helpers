#!/usr/bin/env bash
# Fix for the issue caused by changing SOLUS IO installation directory name from solusnxt to solus on CR nodes
# corresponfing KB article 360012560400

set -euo pipefail

function init() {
    echo "Checking that solusnxt directories exist:"
    [[ ! -d /etc/solusnxt/ ]] && \
        err "Cannot find /etc/solusnxt/ directory\n" \
            "Make sure that the server is correct and directory exists"
    [[ ! -d /usr/local/solusnxt ]] && \
        err "Cannot find /usr/local/solusnxt/ directory\n" \
            "Make sure that the server is correct and directory exists"
	echo "PASS"
}

function move_directories() {
	echo "Copying content from /etc/solusnxt/ to /etc/solus"
	cp -r /etc/solusnxt/ /etc/solus
	echo "Completed"
	
	echo "Removing cache from /usr/local/solusnxt/cache/"
	rm -rf /usr/local/solusnxt/cache/*
	echo "Completed"
	
	echo "Copying content from /usr/local/solusnxt to /usr/local/solus"
	cp -r /usr/local/solusnxt /usr/local/solus
	echo "Completed"
}

function new_agent_service() {
	echo -e "[Unit] \
	\nDescription=Solus Agent \
	\nAfter=network.target \
	\nRequires=network.target \
	\n[Service] \
	\nType=notify \
	\nRestart=always \
	\nRestartSec=5 \
	\nTimeoutStartSec=5 \
	\nTimeoutStopSec=2 \
	\nUser=root \
	\nGroup=root \
	\nExecStart=/usr/local/solus/bin/agent \
	\nExecStartPre=/bin/mkdir -p /var/log/solus \
	\nExecStartPre=/bin/chmod 644 /var/log/solus \
	\n[Install] \
	\nWantedBy=multi-user.target" > /usr/lib/systemd/system/solus-agent.service
}

function update_services() {
	echo "Stopping/disabling old solusnxt-agent.service"
	if [[ ! -f /etc/systemd/system/solusnxt-agent.service ]]; then
		echo "File /etc/systemd/system/solusnxt-agent.service does not exist.Looks like solusnxt-agent.service disabled already"
	else
		systemctl stop solusnxt-agent.service
		systemctl disable solusnxt-agent.service
		mv /etc/systemd/system/solusnxt-agent.service /root/solusnxt-agent.service.backup
		systemctl mask solusnxt-agent.service
		echo "Completed"
	fi
	
	echo "Enabling/starting solus-agent.service"
	systemctl enable solus-agent.service
	systemctl restart solus-agent.service
	systemctl daemon-reload
	sleep 10
	systemctl restart solus-agent.service
}

function main() {
    init
    move_directories
    new_agent_service
    update_services
}

main "$@"
