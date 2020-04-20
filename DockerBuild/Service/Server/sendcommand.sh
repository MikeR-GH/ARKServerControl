#!/bin/bash

: '>>> ADVANCED CONFIG <<<'
CONFIG_FILE="/ARK/Service/Server/commandline.cfg"

if [ -f "${CONFIG_FILE}" ]; then
	eval "`. ${CONFIG_FILE}&>/dev/null
	[ -v ARKSERVER_RCONENABLED ] && declare -p ARKSERVER_RCONENABLED 2>/dev/null
	[ -v ARKSERVER_RCONPASSWORD ] && declare -p ARKSERVER_RCONPASSWORD 2>/dev/null
	[ -v ARKSERVER_RCONPORT ] && declare -p ARKSERVER_RCONPORT 2>/dev/null`"
fi

if [ -z "${1}" ]; then
	echo "Error: Command not given"
	exit 1
fi

if ([ "${ARKSERVER_RCONENABLED}" != "True" ] && [ "${ARKSERVER_RCONENABLED}" != "true" ] && [ "${ARKSERVER_RCONENABLED}" != true ]) || [ ! -v ARKSERVER_RCONPASSWORD ] || [ ! -v ARKSERVER_RCONPORT ]; then
	echo "Error: RCON is not enabled"
	exit 1
fi

COMMAND_RESULT="$(./sendcommand "127.0.0.1:${ARKSERVER_RCONPORT}" "${ARKSERVER_RCONPASSWORD}" "${1}")"
exit "${?}"
