#!/bin/bash

: ' >>> BASIC-SETUP <<< '

CONFIG_FILE="/ARK/Service/Server/commandline.cfg"

: ' >>> ADVANCED-SETUP <<< '

LOGGER="/ARK/log.sh"

: ' >>> METHODS <<< '

function printlog() { # Params: MESSAGE
        if [ -n "${1}" ]; then
                LOGGER_OUTPUT=`${LOGGER} append "${1}" 2>/dev/null`
                [ -n "${LOGGER_OUTPUT}" ] && echo "${LOGGER_OUTPUT}" || echo "${1}"
        fi
}


: ' >>> SCRIPT <<< '

if [ -f "${CONFIG_FILE}" ]; then
	printlog "[DBUG] Importing Commandline-Configuration"
	eval "`. ${CONFIG_FILE}&>/dev/null
	[ -v ARKSERVER_SKIPUPDATE ] && declare -p ARKSERVER_SKIPUPDATE 2>/dev/null
	[ -v ARKSERVER_MAP ] && declare -p ARKSERVER_MAP 2>/dev/null
	[ -v ARKSERVER_RAWSOCKETS ] && declare -p ARKSERVER_RAWSOCKETS 2>/dev/null
	[ -v ARKSERVER_MAXPLAYERS ] && declare -p ARKSERVER_MAXPLAYERS 2>/dev/null
	[ -v ARKSERVER_CLUSTERID ] && declare -p ARKSERVER_CLUSTERID 2>/dev/null
	[ -v ARKSERVER_MODIDS ] && declare -p ARKSERVER_MODIDS 2>/dev/null
	[ -v ARKSERVER_RCONENABLED ] && declare -p ARKSERVER_RCONENABLED 2>/dev/null
	[ -v ARKSERVER_RCONPASSWORD ] && declare -p ARKSERVER_RCONPASSWORD 2>/dev/null
	[ -v ARKSERVER_PORT ] && declare -p ARKSERVER_PORT 2>/dev/null
	[ -v ARKSERVER_QUERYPORT ] && declare -p ARKSERVER_QUERYPORT 2>/dev/null
	[ -v ARKSERVER_RCONPORT ] && declare -p ARKSERVER_RCONPORT 2>/dev/null
	[ -v ARKSERVER_ADDITIONALARGUMENTS ] && declare -p ARKSERVER_ADDITIONALARGUMENTS 2>/dev/null
	[ -v ARKSERVER_ADDITIONALOPTIONS ] && declare -p ARKSERVER_ADDITIONALOPTIONS 2>/dev/null`"
fi

if [ ! -v ARKSERVER_RCONENABLED ]; then
        ARKSERVER_RCONENABLED=False
fi
if [ ! -v ARKSERVER_RCONPORT ] && ([ "${ARKSERVER_RCONENABLED}" == true ] || [ "${ARKSERVER_RCONENABLED}" == "True" ] || [ "${ARKSERVER_RCONENABLED}" == "true" ]); then
        ARKSERVER_RCONPORT=27020
fi

START_TIME=`date +%s`
printlog "[DBUG] Started Service/PauseIdleServer"

STOP_REQUESTED=false
trap "STOP_REQUESTED=true" SIGINT
trap "STOP_REQUESTED=true" SIGKILL
trap "STOP_REQUESTED=true" SIGTERM
trap "STOP_REQUESTED=true" SIGQUIT

SERVER_PAUSED=false

sleep 30s
printlog "[INFO] Service/PauseIdleServer starts to look for idle states"

until [ "${STOP_REQUESTED}" == true ]; do
	CMD_RESULT="$(/ARK/Service/Server/sendcommand.sh ListPlayers)"
	LAST_EXIT_CODE="${?}"

	if [ "${LAST_EXIT_CODE}" -ne 0 ]; then
		if [ "${CMD_RESULT}" = "No Players Connected" ]; then
		        PLAYERS_LIST=""
		else
		        PLAYERS_LIST="${CMD_RESULT}"
		fi

		PLAYER_COUNT=0
		while read -r line; do
		        [ -n "${line}" ] && PLAYER_COUNT=$((${PLAYER_COUNT}+1))
		done <<< "${PLAYERS_LIST}"

		if [ "${SERVER_PAUSED}" == true ]; then
			if [ "${PLAYER_COUNT}" -gt 0 ]; then
				/ARK/Service/Server/sendcommand.sh "SetGlobalPause false" >/dev/null
				if [ "${?}" -eq 0 ]; then
					printlog "[INFO] Unpaused Server"
					SERVER_PAUSED=false
				fi
			fi
		else
			if [ "${PLAYER_COUNT}" -eq 0 ]; then
				/ARK/Service/Server/sendcommand.sh "SetGlobalPause true" >/dev/null
				if [ "${?}" -eq 0 ]; then
					printlog "[INFO] Paused Server"
					SERVER_PAUSED=true
				fi
			fi
		fi
	fi

	sleep 10s
done

printlog "[INFO] Service/PauseIdleServer ran for ${TIME_SPENT_RUNNING} seconds"
if [ "${TIME_SPENT_RUNNING}" -le 60 ]; then
	printlog "[WARN] Service/PauseIdleServer may failed to start"
fi
