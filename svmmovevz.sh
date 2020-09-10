#!/bin/bash

# This is script to change default location of OpenVZ containers
# kb article 360024237152

set -euo pipefail

function dialog() {
  echo " ** Please type full path to the new default directory instead of /vz, for example /home/vz ";
  read -r path;
}

function edit() {
  echo " Backing up main configuration /etc/vz/vz.conf to /root/..."
  cp -a /etc/vz/vz.conf /root/

  echo "Editing current default location to "$path"..."
  sed -i "s!/vz/lock!${path}/lock!g" /etc/vz/vz.conf
  sed -i "s!/vz/dump!${path}/dump!g" /etc/vz/vz.conf
  sed -i "s!/vz/root!${path}/root!g" /etc/vz/vz.conf
  sed -i "s!/vz/private!${path}/private!g" /etc/vz/vz.conf
}

function new_dirs() {
  echo "Creating directories for new location "$path"..."

  mkdir -p ${path}/{root,private,dump,lock}
  chmod 700 ${path}/private/ ${path}/root/

  echo "Default location was changed to "$path". All future containers wil be located there."
  echo "Moving existing container to new location requires their downtime."
  echo "Proceed with moving containers at appropriate time using instruction from https://support.solus.io/hc/en-us/articles/360024237152 "
}

function main() {
  dialog
  edit
  new_dirs
}

main "$@"
