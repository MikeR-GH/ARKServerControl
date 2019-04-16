#!/bin/bash

: ' >>> BASIC-SETUP <<< '

USER="steam"
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

if [ $(id -u) -ne 0 ]; then
	echo "[WARN] Startup-Script must run as root"
	exit 4
fi

: ' Init Log '
sudo -u ${USER} /ARK/log.sh reinit

printlog "[INFO] Startup ARK-Server"
printlog "[DBUG] chown: /ARK"
chown -R ${USER}: /ARK

printlog "[DBUG] Exporting Commandline-Configuration"

[ -f "${CONFIG_FILE}" ] && rm "${CONFIG_FILE}"

[ -v ARKSERVER_SKIPUPDATE ] && declare -p ARKSERVER_SKIPUPDATE 2>/dev/null >>${CONFIG_FILE}
[ -v ARKSERVER_MAP ] && declare -p ARKSERVER_MAP 2>/dev/null >>${CONFIG_FILE}
[ -v ARKSERVER_MAXPLAYERS ] && declare -p ARKSERVER_MAXPLAYERS 2>/dev/null >>${CONFIG_FILE}
[ -v ARKSERVER_CLUSTERID ] && declare -p ARKSERVER_CLUSTERID 2>/dev/null >>${CONFIG_FILE}
[ -v ARKSERVER_MODIDS ] && declare -p ARKSERVER_MODIDS 2>/dev/null >>${CONFIG_FILE}
[ -v ARKSERVER_RCONENABLED ] && declare -p ARKSERVER_RCONENABLED 2>/dev/null >>${CONFIG_FILE}
[ -v ARKSERVER_RCONPASSWORD ] && declare -p ARKSERVER_RCONPASSWORD 2>/dev/null >>${CONFIG_FILE}
[ -v ARKSERVER_PORT ] && declare -p ARKSERVER_PORT 2>/dev/null >>${CONFIG_FILE}
[ -v ARKSERVER_QUERYPORT ] && declare -p ARKSERVER_QUERYPORT 2>/dev/null >>${CONFIG_FILE}
[ -v ARKSERVER_RCONPORT ] && declare -p ARKSERVER_RCONPORT 2>/dev/null >>${CONFIG_FILE}

STOP_REQUESTED=false
UNIX_SIGNAL=""
trap "STOP_REQUESTED=true; UNIX_SIGNAL='SIGINT'" SIGINT
trap "STOP_REQUESTED=true; UNIX_SIGNAL='SIGKILL'" SIGKILL
trap "STOP_REQUESTED=true; UNIX_SIGNAL='SIGTERM'" SIGTERM
trap "STOP_REQUESTED=true; UNIX_SIGNAL='SIGQUIT'" SIGQUIT

printlog "[INFO] Starting Service/ARK-Server.."
/ARK/Service/Server/control.sh start >/dev/null
EXIT_CODE_SERVICE_SERVER=${?}

if [ "${EXIT_CODE_SERVICE_SERVER}" -ne 0 ]; then
	printlog "[WARN] Failed to start Service/ARK-Server"
else
	printlog "[INFO] Starting Service/Restart"
	/ARK/Service/Restart/control.sh start >/dev/null
	EXIT_CODE_SERVICE_RESTART=${?}

	if [ "${EXIT_CODE_SERVICE_RESTART}" -ne 0 ]; then
		printlog "[WARM] Failed to start Service/Restart"
	else
		until [ "${STOP_REQUESTED}" == true ] || ! /ARK/Service/Server/control.sh status >/dev/null; do
			sleep 10s
			if ! /ARK/Service/Restart/control.sh status >/dev/null; then
				printlog "[WARN] Service/Restart has been stopped"
				printlog "[WARN] Restarting Service/Restart"

				/ARK/Service/Restart/control.sh start >/dev/null
				if [ "${?}" -ne 0 ]; then
					printlog "[WARN] Restarting Service/Restart was unsuccessful"
				fi
			fi
		done

		if [ "${STOP_REQUESTED}" == true ]; then
			printlog "[DBUG] Recieved '${UNIX_SIGNAL}' Unix-Signal"
		fi

		if /ARK/Service/Server/control.sh status >/dev/null; then
			printlog "[INFO] Stopping Service/ARK-Server"
			/ARK/Service/Server/control.sh stop >/dev/null
		fi

		/ARK/Service/Server/control.sh join 3 >/dev/null

		if /ARK/Service/Server/control.sh status >/dev/null; then
			printlog "[WARN] Failed to stop Service/ARK-Server"
		else
			printlog "[INFO] Service/ARK-Server has been stopped"
		fi
	fi
fi

: ' Close Log '
sudo -u ${USER} /ARK/log.sh close
