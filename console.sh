#!/bin/bash

DOCKER_SOCKET='/var/run/docker.sock'
SUDO=

usage() {
    PROG="$(basename $0)"
    echo "usage: ${PROG} <container name>"
}

if [ -z "$1" ];
then
    usage
    exit 1
fi
CONTAINER="${1}"

if [ ! -w "${DOCKER_SOCKET}" ];
then
    SUDO='sudo'
fi

$SUDO docker exec -it \
    $CONTAINER \
    /opt/orientdb/bin/console.sh
