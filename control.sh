#!/bin/bash

: ' >>> ADVANCED-SETUP <<< '

PROJECT_NAME="ARKCluster"
SERVERS_BASEDIR="Servers"
BACKUPS_BASEDIR="Backups"

: ' >>> SCRIPT-SETUP <<< ' # // DONT CHANGE THE FOLLOWING..

ARKSERVERCONTROL_NAME="ARKServerControl"
ARKSERVERCONTROL_VERSION="0.2"

# Regex
REGEX_BACKUP_NAME="^[0-9]{4}\-[0-9]{2}\-[0-9]{2}\_[0-9]{2}\-[0-9]{2}\-[0-9]{2}$"

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

function isvalidserver() { # Params: SERVER
	[ -f "${SERVERS_BASEDIR}/${1}/.env" ]
}
function dockercmp() { # Params: SERVER COMMAND
	if isvalidserver "${1}"; then
		docker-compose -f docker-compose.yml -p ${PROJECT_NAME}_${1} --project-directory ${SERVERS_BASEDIR}/${1} ${@:2}
		return ${?}
	fi

	return 1
}
function dockercmp_all() { # Params: COMMAND
	for dir in ${SERVERS_BASEDIR}/*; do
		if isvalidserver "$(basename ${dir})"; then
			dockercmp "$(basename ${dir})" ${@:1}
		fi
	done
}
function backupserver() { # Params: SERVER
	if isvalidserver "${1}"; then
		mkdir -p "${BACKUPS_BASEDIR}/${1}"
		tar -zcvf "${BACKUPS_BASEDIR}/${1}/`date +'%Y-%m-%d_%H-%M-%S'`.tar.gz" -C "${SERVERS_BASEDIR}" "${1}"
		return ${?}
	fi

	return 1
}
function backupserver_all() { # Params:
	for dir in ${SERVERS_BASEDIR}/*; do
		if isvalidserver "$(basename ${dir})"; then
			backupserver "$(basename ${dir})"
		fi
	done
}

echo -e "${COLOR_CYAN}${COLOR_BOLD}===   ${ARKSERVERCONTROL_NAME} v${ARKSERVERCONTROL_VERSION}; Project: ${COLOR_RED}${PROJECT_NAME}${COLOR_CYAN};   ===${COLOR_RESET}\n"

if [ "${1}" == "help" ] || [ "${1}" == "--help" ] || [ -z "${1}" ]; then
	echo "${COLOR_WHITE}${COLOR_BOLD}${0} [--help|list|build|backup [list <?Servername>|all|<Servername>]|recover <Servername> <Backup>|[all|<Servername>] <docker-compose command>]${COLOR_RESET}"
elif [ "${1}" == "list" ]; then
	echo "${COLOR_WHITE}${COLOR_BOLD}List of all Servers:${COLOR_RESET}"
	for dir in ${SERVERS_BASEDIR}/*; do
		if isvalidserver "$(basename ${dir})"; then
			echo "${COLOR_WHITE}${COLOR_BOLD}  - ${COLOR_BLUE}$(basename $dir)${COLOR_RESET}"
		fi
	done
elif [ "${1}" == "build" ]; then
	 docker build --rm $(if [ "${2}" == "no-cache" ]; then echo "--no-cache"; fi) -t arksurvivalevolved DockerBuild/
elif [ "${1}" == "backup" ]; then
	if [ "${2}" == "list" ]; then
		BACKEDUPSERVERS=0
		BACKUPSINTOTAL=0

		for dir in ${BACKUPS_BASEDIR}/*; do
			if [ ! -d "${dir}" ]; then
				continue
			fi
			if [ -z "${3}" ] || [ "$(basename ${dir})" == "${3}" ]; then
				BACKEDUPSERVERS=$((${BACKEDUPSERVERS} + 1))
				BACKUPSINTOTAL=$((${BACKUPSINTOTAL} + $(find ${dir}/*.tar.gz -maxdepth 0 -type f | wc -l)))
			fi
		done

		echo "${COLOR_WHITE}${COLOR_BOLD}${BACKUPSINTOTAL} Backups / ${BACKEDUPSERVERS} Servers:"

		for dir in ${BACKUPS_BASEDIR}/*; do
			if [ ! -d "${dir}" ]; then
				continue
			fi

			if [ -z "${3}" ] || [ "$(basename ${dir})" == "${3}" ]; then
				echo "${COLOR_WHITE}${COLOR_BOLD}  - ${COLOR_BLUE}$(basename ${dir})${COLOR_RESET}"
				for file in ${dir}/*.tar.gz; do
					if [ ! -f "${file}" ]; then
						continue
					fi
					BACKUP_NAME="$(basename ${file} .tar.gz)"
					if [[ ${BACKUP_NAME} =~ ${REGEX_BACKUP_NAME} ]]; then
						echo "${COLOR_WHITE}${COLOR_BOLD}    - ${COLOR_CYAN}$(basename ${file} .tar.gz)${COLOR_RESET}"
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

	if [ ! -f "${BACKUPS_BASEDIR}/${2}/${3}.tar.gz" ]; then
		echo "${COLOR_RED}${COLOR_BOLD}Backup '${3}' does not exist.${COLOR_RESET}"
		exit 1
	fi

	echo "${COLOR_YELLOW}${COLOR_BOLD}Deleting current server files of ${COLOR_BLUE}${2}${COLOR_YELLOW}..${COLOR_RESET}"
	rm -rf ${SERVERS_BASEDIR}/${2} &>/dev/null
	echo "${COLOR_GREEN}${COLOR_BOLD}Recovering backup ${COLOR_CYAN}${3}${COLOR_GREEN}..${COLOR_RESET}"
	tar -zxvf "${BACKUPS_BASEDIR}/${2}/${3}.tar.gz" -C "${SERVERS_BASEDIR}"
	if [ "${?}" -eq 0 ]; then
		echo "${COLOR_GREEN}${COLOR_BOLD}Successfully recovered backup ${COLOR_BLUE}${2}${COLOR_GREEN} / ${COLOR_CYAN}${3}${COLOR_GREEN}!${COLOR_RESET}"
	else
		echo "${COLOR_RED}${COLOR_BOLD}Failed to recover backup ${COLOR_BLUE}${2}${COLOR_RED} / ${COLOR_CYAN}${3}${COLOR_RED}!${COLOR_RESET}"
	fi
elif [ "${1}" == "all" ]; then
	if [[ -z "${@:2}" ]]; then
		dockercmp_all ps
	else
		dockercmp_all ${@:2}
	fi
else
	if ! isvalidserver "${1}"; then
		echo "${COLOR_RED}${COLOR_BOLD}${1} is not a valid server!${COLOR_RESET}"
		echo "${COLOR_WHITE}${COLOR_BOLD}i.e. the server directory must contain a .env-file.${COLOR_RESET}"
		exit 1
	fi

	if [[ -z "${@:2}" ]]; then
		dockercmp ${1} ps
	else
		dockercmp ${1} ${@:2}
	fi
fi
