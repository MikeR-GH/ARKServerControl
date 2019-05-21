#!/bin/bash

: ' >>> ADVANCED-SETUP <<< '

PROJECT_NAME="ARKCluster"
SERVERS_BASEDIR="Servers"
BACKUPS_BASEDIR="Backups"

: ' >>> SCRIPT-SETUP <<< ' # // DONT CHANGE THE FOLLOWING..

ARKSERVERCONTROL_NAME="ARKServerControl"
ARKSERVERCONTROL_VERSION="0.4"

# Regex
REGEX_BACKUP_NAME="^[0-9]{4}\-[0-9]{2}\-[0-9]{2}\_[0-9]{2}\-[0-9]{2}\-[0-9]{2}$"
REGEX_LOG_NAME="^[0-9]{4}\-[0-9]{2}\-[0-9]{2}\_[0-9]{2}\-[0-9]{2}\-[0-9]{2}$"

# tput-COLORS
COLOR_WHITE="$(tput setaf 7 2>/dev/null)"
COLOR_RED="$(tput setaf 1 2>/dev/null)"
COLOR_GREEN="$(tput setaf 2 2>/dev/null)"
COLOR_YELLOW="$(tput setaf 3 2>/dev/null)"
COLOR_CYAN="$(tput setaf 6 2>/dev/null)"
COLOR_BLUE="$(tput setaf 4 2>/dev/null)"

COLOR_BOLD="$(tput bold 2>/dev/null)"
#COLOR_UNDERLINE="$(tput smul 2>/dev/null)"
#COLOR_UNDERLINE_END="$(tput rmul 2>/dev/null)"
#COLOR_ITALIC="$(tput sitm 2>/dev/null)"
#COLOR_ITALIC_END="$(tput ritm 2>/dev/null)"
#COLOR_BLINK="$(tput blink 2>/dev/null)"
#COLOR_REVERSE="$(tput rev 2>/dev/null)"
#COLOR_INVISIBLE="$(tput invis 2>/dev/null)"

COLOR_RESET="$(tput sgr0 2>/dev/null)"

BINDIR=$(dirname "$(readlink -fn "$0")")
cd "$BINDIR"

function rootdir() {
	if [ -n "${1}" ]; then
		ROOTDIR="${1}"
		until [ "$(dirname ${ROOTDIR})" == "/" ] || [ "$(dirname ${ROOTDIR})" == "." ]; do
			ROOTDIR="$(dirname ${ROOTDIR})"
		done
	fi
	echo "${ROOTDIR}"
}
function isvalidserver() { # Params: SERVER
	[ -f "${SERVERS_BASEDIR}/${1}/.env" ]
}
function isserver() { # Params: SERVER
	isvalidserver "${1}" && [ -n "$(dockercmp "${1}" ps -q)" ]
}
function dockercmp() { # Params: SERVER COMMAND
	if isvalidserver "${1}"; then
		docker-compose -f docker-compose.yml -p ${PROJECT_NAME}_${1} --project-directory ${SERVERS_BASEDIR}/${1} ${@:2}
		return ${?}
	fi

	return 1
}
function backupserver() { # Params: SERVER
	if isvalidserver "${1}"; then
		mkdir -p "${SERVERS_BASEDIR}/${1}/${BACKUPS_BASEDIR}"
		tar -zcvf "${SERVERS_BASEDIR}/${1}/${BACKUPS_BASEDIR}/`date +'%Y-%m-%d_%H-%M-%S'`.tar.gz" -C "${SERVERS_BASEDIR}" --exclude "${1}/${BACKUPS_BASEDIR}" "${1}"
		return ${?}
	fi

	return 1
}
function backupserver_all() { # Params:
	for dir in ${SERVERS_BASEDIR}/*; do
		local SERVER_NAME="$(basename ${dir})"
		if isvalidserver "${SERVER_NAME}"; then
			backupserver "${SERVER_NAME}"
		fi
	done
}

echo -e "${COLOR_CYAN}${COLOR_BOLD}===   ${ARKSERVERCONTROL_NAME} v${ARKSERVERCONTROL_VERSION}; Project: ${COLOR_RED}${PROJECT_NAME}${COLOR_CYAN};   ===${COLOR_RESET}\n"

if [ "${1}" == "help" ] || [ "${1}" == "--help" ] || [ -z "${1}" ]; then
	echo "${COLOR_WHITE}${COLOR_BOLD}${0} [--help|list|build|backup [list <?Servername>|all|<Servername>]|recover <Servername> <Backup>|[<Servername> log [?follow|f]|[all|<Servername>] <docker-compose command>]]${COLOR_RESET}"
elif [ "${1}" == "list" ]; then
	echo "${COLOR_WHITE}${COLOR_BOLD}List of all Servers:${COLOR_RESET}"
	for dir in ${SERVERS_BASEDIR}/*; do
		if isvalidserver "$(basename ${dir})"; then
			echo "${COLOR_WHITE}${COLOR_BOLD}  - ${COLOR_BLUE}$(basename $dir)${COLOR_RESET}"
		fi
	done
elif [ "${1}" == "info" ]; then
	if [ -z "${2}" ] || [ "${2}" == "--profile-url" ] || [ "${2}" == "--url" ]; then
		counter=0
		for dir in ${SERVERS_BASEDIR}/*; do
			SERVER_NAME="$(basename ${dir})"
			if isvalidserver "${SERVER_NAME}"; then
				if [ "${counter}" -le 0 ]; then
					counter=$((${counter}+1))
				else
					echo ""
				fi

				SERVER_ONLINE=$(isserver "${SERVER_NAME}"; echo "${?}")
				echo -n "${COLOR_WHITE}${COLOR_BOLD}=> ${COLOR_BLUE}${SERVER_NAME}${COLOR_WHITE}   ("
				[ "${SERVER_ONLINE}" -eq 0 ] && echo -n "${COLOR_GREEN}Online" || echo -n "${COLOR_RED}Offline"
				echo "${COLOR_WHITE})${COLOR_RESET}"
				[ "${SERVER_ONLINE}" -eq 0 ] && dockercmp "${SERVER_NAME}" exec ARKServer /ARK/Service/Server/listplayers.sh "$(([ "${2}" == "--profile-url" ] || [ "${2}" == "--url" ]) && echo "${2}")"
			fi
		done
	else
		SERVER_NAME="${2}"
		if ! isvalidserver "${SERVER_NAME}"; then
			echo "${COLOR_RED}${COLOR_BOLD}${1} is not a valid server!${COLOR_RESET}"
			echo "${COLOR_WHITE}${COLOR_BOLD}i.e. the server directory must contain a .env-file.${COLOR_RESET}"
			exit 1
		fi

		SERVER_ONLINE=$(isserver "${SERVER_NAME}"; echo "${?}")
		echo -n "${COLOR_WHITE}${COLOR_BOLD}=> ${COLOR_BLUE}${SERVER_NAME}${COLOR_WHITE}   ("
		[ "${SERVER_ONLINE}" -eq 0 ] && echo -n "${COLOR_GREEN}Online" || echo -n "${COLOR_RED}Offline"
		echo "${COLOR_WHITE})${COLOR_RESET}"

		[ "${SERVER_ONLINE}" -eq 0 ] && dockercmp "${SERVER_NAME}" exec ARKServer /ARK/Service/Server/listplayers.sh "$(([ "${3}" == "--profile-url" ] || [ "${3}" == "--url" ]) && echo "${3}")"
	fi
elif [ "${1}" == "build" ]; then
	 docker build --rm $(if [ "${2}" == "no-cache" ]; then echo "--no-cache"; fi) -t arksurvivalevolved DockerBuild/
elif [ "${1}" == "backup" ]; then
	if [ "${2}" == "list" ]; then
		BACKEDUPSERVERS=0
		BACKUPSINTOTAL=0

		for dir in ${SERVERS_BASEDIR}/*; do
			SERVER_NAME="$(basename ${dir})"
			if isvalidserver "${SERVER_NAME}" && ([ -z "${3}" ] || [ "${SERVER_NAME}" == "${3}" ]); then
				BACKEDUPSERVERS=$((${BACKEDUPSERVERS} + 1))
				BACKUPSINTOTAL=$((${BACKUPSINTOTAL} + $(find ${dir}/${BACKUPS_BASEDIR}/*.tar.gz -maxdepth 0 -type f | wc -l)))
			fi
		done

		echo "${COLOR_WHITE}${COLOR_BOLD}${BACKUPSINTOTAL} Backups / ${BACKEDUPSERVERS} Servers:"

		for dir in ${SERVERS_BASEDIR}/*; do
			SERVER_NAME="$(basename ${dir})"
			if isvalidserver "${SERVER_NAME}" && ([ -z "${3}" ] || [ "${SERVER_NAME}" == "${3}" ]); then
				echo "${COLOR_WHITE}${COLOR_BOLD}  - ${COLOR_BLUE}${SERVER_NAME}${COLOR_RESET}"
				for file in ${dir}/${BACKUPS_BASEDIR}/*.tar.gz; do
					if [ ! -f "${file}" ]; then
						continue
					fi
					BACKUP_NAME="$(basename ${file} .tar.gz)"
					if [[ ${BACKUP_NAME} =~ ${REGEX_BACKUP_NAME} ]]; then
						echo "${COLOR_WHITE}${COLOR_BOLD}    - ${COLOR_CYAN}${BACKUP_NAME}${COLOR_RESET}"
					fi
				done
			fi
		done
	elif [ "${2}" == "all" ]; then
		backupserver_all
	else
		backupserver "${2}"
	fi
elif [ "${1}" == "recover" ]; then
	if [ -z "${3}" ] || ! [[ ${3} =~ ${REGEX_BACKUP_NAME} ]]; then
		echo "${COLOR_RED}${COLOR_BOLD}No valid backup given${COLOR_RESET}"
		exit 1
	fi

	if ! isvalidserver "${2}"; then
                echo "${COLOR_RED}${COLOR_BOLD}${1} is not a valid server!${COLOR_RESET}"
                echo "${COLOR_WHITE}${COLOR_BOLD}i.e. the server directory must contain a .env-file.${COLOR_RESET}"
                exit 1
        fi

	if [ "$(dockercmp ${2} ps -q | wc -l)" -gt 0 ]; then
		echo "${COLOR_RED}${COLOR_BOLD}${2} is still running. The server must be stopped in order to recover a backup.${COLOR_RESET}"
		exit 1
	fi

	if [ ! -f "${SERVERS_BASEDIR}/${2}/${BACKUPS_BASEDIR}/${3}.tar.gz" ]; then
		echo "${COLOR_RED}${COLOR_BOLD}Backup '${3}' does not exist.${COLOR_RESET}"
		exit 1
	fi

	echo "${COLOR_YELLOW}${COLOR_BOLD}Deleting current server files of ${COLOR_BLUE}${2}${COLOR_YELLOW}..${COLOR_RESET}"
	DID_REMOVE_FILES=false
	for dir in ${SERVERS_BASEDIR}/${2}/*; do
		if [ "$(basename ${dir})" != "$(rootdir ${BACKUPS_BASEDIR})" ]; then
			echo "${COLOR_RED}${COLOR_BOLD}Removing${COLOR_YELLOW} ${dir}${COLOR_RESET}"
			rm -rf ${dir} &>/dev/null
			DID_REMOVE_FILES=true
		fi
	done
	if [ "${DID_REMOVE_FILES}" == false ]; then
		echo "${COLOR_YELLOW}${COLOR_BOLD}No files were removed.${COLOR_RESET}"
	fi

	DIRS_IN_ARCHIVE="$(tar --exclude="*/*" -tf "Servers/05Test/Backups/2019-04-27_07-43-53.tar.gz")"
	DIRS_IN_ARCHIVE_COUNT="$(echo "${DIRS_IN_ARCHIVE}" | wc -l)"
	if [ "${DIRS_IN_ARCHIVE_COUNT}" -ne 1 ] &>/dev/null; then
		echo "${COLOR_RED}${COLOR_BOLD}Failed to determine the Server directory within the Backup.${COLOR_RESET}"
		exit 1
	fi
	BACKUP_SERVER_DIRNAME="$(basename ${DIRS_IN_ARCHIVE})"

	echo "${COLOR_GREEN}${COLOR_BOLD}Recovering backup ${COLOR_CYAN}${3}${COLOR_GREEN}..${COLOR_RESET}"
	tar -zxvf "${SERVERS_BASEDIR}/${2}/${BACKUPS_BASEDIR}/${3}.tar.gz" -C "${SERVERS_BASEDIR}/${2}" "${BACKUP_SERVER_DIRNAME}" --strip-components=1
	if [ "${?}" -eq 0 ]; then
		echo "${COLOR_GREEN}${COLOR_BOLD}Successfully recovered backup ${COLOR_BLUE}${2}${COLOR_GREEN} / ${COLOR_CYAN}${3}${COLOR_GREEN}!${COLOR_RESET}"
	else
		echo "${COLOR_RED}${COLOR_BOLD}Failed to recover backup ${COLOR_BLUE}${2}${COLOR_RED} / ${COLOR_CYAN}${3}${COLOR_RED}!${COLOR_RESET}"
	fi
elif [ "${1}" == "all" ]; then
	COMMAND="${@:2}"
	if [ -z "${COMMAND}" ]; then
		COMMAND="ps"
	fi

	VALID_SERVERS_COUNT=0
	for dir in ${SERVERS_BASEDIR}/*; do
		if isvalidserver "$(basename ${dir})"; then
			VALID_SERVERS_COUNT=$((${VALID_SERVERS_COUNT} + 1))
		fi
	done

	if [ "${VALID_SERVERS_COUNT}" -eq 0 ]; then
		echo "${COLOR_RED}${COLOR_BOLD}No servers were found.${COLOR_RESET}"
	else
		for dir in ${SERVERS_BASEDIR}/*; do
			SERVER_NAME="$(basename ${dir})"
			if isvalidserver "${SERVER_NAME}"; then
				echo "${COLOR_YELLOW}${COLOR_BOLD}Executing command for server ${COLOR_BLUE}${SERVER_NAME}${COLOR_YELLOW} ..${COLOR_RESET}"
				dockercmp "${SERVER_NAME}" "${COMMAND}"
				echo ""
			fi
		done
	fi
else
	if ! isvalidserver "${1}"; then
		echo "${COLOR_RED}${COLOR_BOLD}${1} is not a valid server!${COLOR_RESET}"
		echo "${COLOR_WHITE}${COLOR_BOLD}i.e. the server directory must contain a .env-file.${COLOR_RESET}"
		exit 1
	fi

	if [ "${2}" == "log" ]; then
		LOG_FILE=""
		for file in Servers/${1}/ServiceLogs/*; do
			LOG_NAME="$(basename ${file} .log)"
			if [ -f "${file}" ] && [[ ${LOG_NAME} =~ ${REGEX_LOG_NAME} ]]; then
				LOG_FILE="${file}"
			fi
		done
		unset -v LOG_NAME

		if [ -z "${LOG_FILE}" ]; then
			echo "${COLOR_ÝELLOW}${COLOR_BOLD}No log found.${COLOR_RESET}"
		else
			echo "${COLOR_GREEN}${COLOR_BOLD}Displaying Log '${COLOR_CYAN}$(basename ${LOG_FILE} .log)${COLOR_GREEN}'..${COLOR_RESET}"

			if [ "${3}" == "follow" ] || [ "${3}" == "f" ]; then
				tail -f -n 100 "${LOG_FILE}" |less
			else
				tail -n 100 "${LOG_FILE}" |less
			fi
		fi
	else
		if [[ -z "${@:2}" ]]; then
			dockercmp ${1} ps
		else
			dockercmp ${1} ${@:2}
		fi
	fi
fi
