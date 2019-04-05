#!/bin/bash

EFFECTIVE_TARGET_USER="steam"
LOG_DIRECTORY="/ArkSurvivalEvolved/StartupLogs"

MINIMAL_RUNNING_TIME=10
NORMAL_MINIMAL_RUNNING_TIME=60

#### Cache
if [ ! -v START_TIME ]; then
	START_TIME="$(date +%s)"
fi
if [ ! -v LOG_FILE ]; then
	LOG_FILE="$(date +'%Y-%m-%d_%H-%M-%S').log"
fi

function printlog() { # Params: MESSAGE
	if [[ ! -z "${1}" ]]; then
		DATE_STRING="$(date +'%Y-%m-%d_%H-%M-%S')  ||  "
		echo -e "${DATE_STRING}${1}"
		echo -e "${DATE_STRING}${1}" >> ${LOG_DIRECTORY}/${LOG_FILE}
	fi
}

if [ $(id -u) -eq 0 ]; then
	printlog "chown: /ArkSurvivalEvolved"
	chown -R ${EFFECTIVE_TARGET_USER}: /ArkSurvivalEvolved

	printlog "Updating ARKSurvivalEvolved.."
	UPDATING_START="$(date +%s)"
	sudo -u ${EFFECTIVE_TARGET_USER} /SteamCMD/steamcmd.sh \
		+@ShutdownOnFailedCommand 1 \
		+@NoPromptForPassword 1 \
		+login anonymous \
		+force_install_dir /ArkSurvivalEvolved \
		+app_update 376030 validate \
		+quit

	UPDATING_EXITCODE="$?"

	printlog "Updating ARKSurvivalEvolved took $(($(date +%s) - ${UPDATING_START})) seconds"

	if [ "${UPDATING_EXITCODE}" -ne 0 ]; then
		printlog "Updating failed. Aborting startup.."
		exit 3
	fi

	if [ ! -h "/ArkSurvivalEvolved/Engine/Binaries/ThirdParty/SteamCMD/Linux" ]; then
		if [ -e "/ArkSurvivalEvolved/Engine/Binaries/ThirdParty/SteamCMD/Linux" ]; then
			rm -rf "/ArkSurvivalEvolved/Engine/Binaries/ThirdParty/SteamCMD/Linux"
		fi
		ln -s /SteamCMD /ArkSurvivalEvolved/Engine/Binaries/ThirdParty/SteamCMD/Linux
	fi

	printlog "chown: /ArkSurvivalEvolved"
	chown -R ${EFFECTIVE_TARGET_USER}: /ArkSurvivalEvolved
fi

if [ "$(whoami)" != "${EFFECTIVE_TARGET_USER}" ]; then
        printlog "Switching to user '${EFFECTIVE_TARGET_USER}'.."
	FULL_COMMAND_LINE="${0} ${@}"
        exec sudo -u ${EFFECTIVE_TARGET_USER} --preserve-env=ARKSERVER_MAP,ARKSERVER_PORT,ARKSERVER_QUERYPORT,ARKSERVER_RCONENABLED,ARKSERVER_RCONPORT,ARKSERVER_MAXPLAYERS,ARKSERVER_ADDITIONALOPTIONS,ARKSERVER_ADDITIONALARGUMENTS -- sh -c "START_TIME=\"${START_TIME}\" LOG_FILE=\"${LOG_FILE}\" exec ${FULL_COMMAND_LINE}"
        exit $?
fi

printlog "Compiling Commandline.."

if [ ! -v ARKSERVER_MAP ]; then
	printlog "Returning to default 'ARKSERVER_MAP=\"TheIsland\"'"
	ARKSERVER_MAP="TheIsland"
fi
if [ ! -v ARKSERVER_PORT ]; then
	printlog "Returning to default 'ARKSERVER_PORT=7777'"
	ARKSERVER_PORT=7777
fi
if [ ! -v ARKSERVER_QUERYPORT ]; then
	printlog "Returning to default 'ARKSERVER_QUERYPORT'"
	ARKSERVER_QUERYPORT=27015
fi
if [ ! -v ARKSERVER_RCONENABLED ]; then
        printlog "Returning to default 'ARKSERVER_RCONENABLED=False'"
        ARKSERVER_RCONENABLED=False
fi
if [ ! -v ARKSERVER_RCONPORT ] && ([ "${ARKSERVER_RCONENABLED}" == "True" ] || [ "${ARKSERVER_RCONENABLED}" == "true" ]); then
	printlog "Returning to default 'ARKSERVER_RCONPORT=27020'"
	ARKSERVER_RCONPORT=27020
fi
if [ ! -v ARKSERVER_MAXPLAYERS ]; then
	printlog "Returning to default 'ARKSERVER_MAXPLAYERS=70'"
	ARKSERVER_MAXPLAYERS=70
fi

COMMANDLINE="/ArkSurvivalEvolved/ShooterGame/Binaries/Linux/ShooterGameServer"
COMMANDLINE="${COMMANDLINE} \""
COMMANDLINE="${COMMANDLINE}${ARKSERVER_MAP}"
COMMANDLINE="${COMMANDLINE}?listen"
COMMANDLINE="${COMMANDLINE}?bRawSockets"
COMMANDLINE="${COMMANDLINE}?Port=${ARKSERVER_PORT}"
COMMANDLINE="${COMMANDLINE}?QueryPort=${ARKSERVER_QUERYPORT}"
COMMANDLINE="${COMMANDLINE}?RCONEnabled=${ARKSERVER_RCONENABLED}"

if [ "${ARKSERVER_RCONENABLED}" == "True" ] || [ "${ARKSERVER_RCONENABLED}" == "true" ]; then
	COMMANDLINE="${COMMANDLINE}?RCONPort=${ARKSERVER_RCONPORT}"
	COMMANDLINE="${COMMANDLINE}?ServerAdminPassword=${ARKSERVER_RCONPASSWORD}"
fi
COMMANDLINE="${COMMANDLINE}?MaxPlayers=${ARKSERVER_MAXPLAYERS}"

: 'Adding additional options'
if [ -v ARKSERVER_ADDITIONALOPTIONS ]; then
	COMMANDLINE="${COMMANDLINE}${ARKSERVER_ADDITIONALOPTIONS}"
fi

: 'Closing Commandline-Options'
COMMANDLINE="${COMMANDLINE}\""

: 'Adding Arguments'
if [ -v CLUSTERID ]; then
	COMMANDLINE="${COMMANDLINE} -NoTransferFromFiltering"
	COMMANDLINE="${COMMANDLINE} -clusterid=${CLUSTERID}"
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
	COMMANDLINE="${COMMANDLINE} ${ARKSERVER_ADDITIONALARGUMENTS}"
fi

printlog "Executing: ${COMMANDLINE}"
exec `${COMMANDLINE}`

RUNNING_TIME="$(($(date +%s) - ${START_TIME}))"


TIME_LEFT_NORMAL="$((${NORMAL_MINIMAL_RUNNING_TIME} - ${RUNNING_TIME}))"
if [ "${TIME_LEFT_NORMAL}" -ge 0 ]; then
        printlog "ARKServer only ran for ${RUNNING_TIME} seconds. It seems it didn't start up correctly."
fi

TIME_LEFT="$((${MINIMAL_RUNNING_TIME} - ${RUNNING_TIME}))"
if [ "${TIME_LEFT}" -ge 0 ]; then
	printlog "Sleeping ${TIME_LEFT} seconds"
	sleep ${TIME_LEFT}s
fi
