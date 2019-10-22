#!/usr/bin/env bash
# The script creates a backup of SolusVM database and puts it into the current directory
# KCS article #360009293960

set -euo pipefail

# Creates a backup of the database and moves it to the proper location
# Globals: MYSQL_PASS MYSQL_DB MYSQL_USER TMPNAME
function backup() {
    local bkp_name
    MYSQL_PWD="${MYSQL_PASS}" mysqldump -u"${MYSQL_USER}" "${MYSQL_DB}" > "${TMPNAME}"
    bkp_name="solusvmdb$(date +%F_%H.%M).sql"
    mv "${TMPNAME}" "$bkp_name"

    echo "Backup file $(pwd)/$bkp_name has been created"
}

# Checks whether the MySQL credential file exists and can be read
# Globals: +MYSQL_PASS +MYSQL_DB +MYSQL_USER +TMPNAME
function init() {
    [[ ! -f /usr/local/solusvm/includes/solusvm.conf ]] && \
        err "Cannot create backup: /usr/local/solusvm/includes/solusvm.conf does not exist\n" \
            "Make sure that the server is correct and SolusVM Master software is installed"
    [[ ! -r /usr/local/solusvm/includes/solusvm.conf ]] && \
        err "Cannot create backup: /usr/local/solusvm/includes/solusvm.conf cannot be read by the current user"

    MYSQL_PASS="$(cut -d':' -f3 /usr/local/solusvm/includes/solusvm.conf)"
    MYSQL_USER="$(cut -d':' -f2 /usr/local/solusvm/includes/solusvm.conf)"
    MYSQL_DB="$(cut -d':' -f1 /usr/local/solusvm/includes/solusvm.conf)"

    TMPNAME="$(mktemp /tmp/svmdump.XXXXXX)"

    echo "Backup of SolusVM database has started..."
}

# Stops script execution with an error
# Args: $* any
function err() {
    echo -e "$*" >&2
    exit 1
}

function main() {
    init
    backup
}

main "$@"
