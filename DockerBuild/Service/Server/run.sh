#!/bin/bash

: ' >>> BASIC-SETUP <<< '

USER="steam"
CONFIG_FILE="/ARK/Service/Server/commandline.cfg"
CONFIG_OVERRIDE_DIRECTORY="/ARK/Server/ConfigOverride"
CONFIG_DIRECTORY="/ARK/Server/ShooterGame/Saved/Config/LinuxServer"

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

if [ "$(whoami)" != "${USER}" ]; then
	printlog "[WARN] ARK-Server has to run under '${USER}' != '$(whoami)' user"
	exit 3
fi

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
	[ -v ARKSERVER_RCONPORT ] && declare -p ARKSERVER_RCONPORT 2>/dev/null`"
fi

if [ "${ARKSERVER_SKIPUPDATE}" == "True" ] || [ "${ARKSERVER_SKIPUPDATE}" == "true" ]; then
	printlog "[INFO] Skipping Update due to configuration"
else
	printlog "[INFO] Updating ARK-Server"
	UPDATING_START=`date +%s`
	/SteamCMD/steamcmd.sh \
		+@ShutdownOnFailedCommand 1 \
		+@NoPromptForPassword 1 \
		+login anonymous \
		+force_install_dir /ARK/Server \
		+app_update 376030 validate \
		+quit

	UPDATING_EXITCODE="$?"

	printlog "[INFO] Updating ARK-Server took $(($(date +%s) - ${UPDATING_START})) seconds"

	if [ "${UPDATING_EXITCODE}" -ne 0 ]; then
		printlog "[WARN] Updating failed. Startup aborted"
		exit 3
	fi
fi

printlog "[DBUG] Linking SteamCMD/Linux-Directory.."

if [ ! -h "/ARK/Server/Engine/Binaries/ThirdParty/SteamCMD/Linux" ]; then
	if [ -e "/ARK/Server/Engine/Binaries/ThirdParty/SteamCMD/Linux" ]; then
		rm -rf "/ARK/Server/Engine/Binaries/ThirdParty/SteamCMD/Linux"
	fi
	ln -s /SteamCMD /ARK/Server/Engine/Binaries/ThirdParty/SteamCMD/Linux
fi

if [ -d "${CONFIG_OVERRIDE_DIRECTORY}" ]; then
	printlog "[DBUG] Preparing Configuration-Overrides"

	for file in ${CONFIG_OVERRIDE_DIRECTORY}/*; do
		if [ ! -f "${file}" ]; then
			continue
		fi

		filename=$(basename ${file})

		if [ -f "${CONFIG_DIRECTORY}/${filename}" ]; then
			rm ${CONFIG_DIRECTORY}/${filename} &>/dev/null
		fi

		if [ "${?}" -ne 0 ] || [ -f "${CONFIG_DIRECTORY}/${filename}" ]; then
			printlog "[WARN] Failed to remove file '${filename}' for override purpose"
		else
			cp ${CONFIG_OVERRIDE_DIRECTORY}/${filename} ${CONFIG_DIRECTORY}/${filename} &>/dev/null
			if [ "${?}" -ne 0 ] || [ ! -f "${CONFIG_DIRECTORY}/${filename}" ]; then
				printlog "[WARN] Failed to copy file '${filename}' for override purpose"
			else
				printlog "[DBUG] Copied file '${filename}' for override purpose"
			fi
		fi
	done
fi

printlog "[DBUG] Compiling Commandline.."

if [ ! -v ARKSERVER_MAP ]; then
        printlog "[DBUG] Returning to default 'ARKSERVER_MAP=\"TheIsland\"'"
        ARKSERVER_MAP="TheIsland"
fi
if [ ! -v ARKSERVER_PORT ]; then
        printlog "[DBUG] Returning to default 'ARKSERVER_PORT=7777'"
        ARKSERVER_PORT=7777
fi
if [ ! -v ARKSERVER_QUERYPORT ]; then
        printlog "[DBUG] Returning to default 'ARKSERVER_QUERYPORT'"
        ARKSERVER_QUERYPORT=27015
fi
if [ ! -v ARKSERVER_RCONENABLED ]; then
        printlog "[DBUG] Returning to default 'ARKSERVER_RCONENABLED=False'"
        ARKSERVER_RCONENABLED=False
fi
if [ ! -v ARKSERVER_RCONPORT ] && ([ "${ARKSERVER_RCONENABLED}" == "True" ] || [ "${ARKSERVER_RCONENABLED}" == "true" ]); then
        printlog "[DBUG] Returning to default 'ARKSERVER_RCONPORT=27020'"
        ARKSERVER_RCONPORT=27020
fi
if [ ! -v ARKSERVER_MAXPLAYERS ]; then
        printlog "[DBUG] Returning to default 'ARKSERVER_MAXPLAYERS=70'"
        ARKSERVER_MAXPLAYERS=70
fi

COMMANDLINE="/ARK/Server/ShooterGame/Binaries/Linux/ShooterGameServer"
COMMANDLINE="${COMMANDLINE} \""
COMMANDLINE="${COMMANDLINE}${ARKSERVER_MAP}"
COMMANDLINE="${COMMANDLINE}?listen"

if [ "${ARKSERVER_RAWSOCKETS}" == "True" ] || [ "${ARKSERVER_RAWSOCKETS}" == "true" ]; then
	COMMANDLINE="${COMMANDLINE}?bRawSockets"
fi

COMMANDLINE="${COMMANDLINE}?Port=${ARKSERVER_PORT}"
COMMANDLINE="${COMMANDLINE}?QueryPort=${ARKSERVER_QUERYPORT}"
if [ -n "${ARKSERVER_MODIDS}" ]; then
	COMMANDLINE="${COMMANDLINE}?GameModIds=${ARKSERVER_MODIDS}"
fi
COMMANDLINE="${COMMANDLINE}?RCONEnabled=${ARKSERVER_RCONENABLED}"

if [ "${ARKSERVER_RCONENABLED}" == "True" ] || [ "${ARKSERVER_RCONENABLED}" == "true" ]; then
	printlog "[DBUG] Enabling RCONPort ${ARKSERVER_RCONPORT} (Password:$([ -n \"${ARKSERVER_RCONPASSWORD}\" ] && echo '***' || echo 'n/a'))"
        COMMANDLINE="${COMMANDLINE}?RCONPort=${ARKSERVER_RCONPORT}"
        COMMANDLINE="${COMMANDLINE}?ServerAdminPassword=${ARKSERVER_RCONPASSWORD}"
fi
COMMANDLINE="${COMMANDLINE}?MaxPlayers=${ARKSERVER_MAXPLAYERS}"

: 'Adding additional options'
if [ -v ARKSERVER_ADDITIONALOPTIONS ]; then
	printlog "[DBUG] Passing additional options"
        COMMANDLINE="${COMMANDLINE}${ARKSERVER_ADDITIONALOPTIONS}"
fi

: 'Closing Commandline-Options'
COMMANDLINE="${COMMANDLINE}\""

: 'Adding Arguments'
if [ -v ARKSERVER_CLUSTERID ]; then
	printlog "[DBUG] Enabling Cluster (ID: '${ARKSERVER_CLUSTERID}')"
        COMMANDLINE="${COMMANDLINE} -NoTransferFromFiltering"
	COMMANDLINE="${COMMANDLINE} -ClusterDirOverride=/ARK/Server/ShooterGame/ClusterTransfers"
        COMMANDLINE="${COMMANDLINE} -clusterid=${ARKSERVER_CLUSTERID}"
fi

COMMANDLINE="${COMMANDLINE} -USEALLAVAILABLECORES"
COMMANDLINE="${COMMANDLINE} -usecache"
COMMANDLINE="${COMMANDLINE} -lowmemory"
COMMANDLINE="${COMMANDLINE} -nosound"
COMMANDLINE="${COMMANDLINE} -sm4"
COMMANDLINE="${COMMANDLINE} -server"
COMMANDLINE="${COMMANDLINE} -servergamelog"
COMMANDLINE="${COMMANDLINE} -log"
COMMANDLINE="${COMMANDLINE} -servergamelogincludetribelogs"

if [ -v ARKSERVER_ADDITIONALARGUMENTS ]; then
	printlog "[DBUG] Passing additional arguments"
        COMMANDLINE="${COMMANDLINE} ${ARKSERVER_ADDITIONALARGUMENTS}"
fi

START_TIME=`date +%s`
printlog "[DBUG] Executing: ${COMMANDLINE}"
exec `${COMMANDLINE}`
ARKSERVER_EXITCODE="${?}"
TIME_SPENT="$(($(date +%s) - ${START_TIME}))"

printlog "[INFO] ARK-Server exit code: ${ARKSERVER_EXITCODE}"
if [ "${ARKSERVER_EXITCODE}" -ne 0 ]; then
	printlog "[WARN] ARK-Server exited with non-zero code"
fi

printlog "[INFO] ARK-Server ran for ${RUNNING_TIME} seconds"
if [ "${TIME_SPENT}" -le 60 ]; then
	printlog "[WARN] ARK-Server may failed to start"
fi
