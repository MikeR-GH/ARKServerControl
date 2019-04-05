#!/bin/bash

PROJECT_NAME="ARKCluster"
SERVERS_BASEDIR="Servers"



ARKSERVERCONTROL_NAME="ARKServerControl"
ARKSERVERCONTROL_VERSION="0.1"

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


function isvalidserver() { # Params: SERVER
	[ -f "${SERVERS_BASEDIR}/${1}/.env" ]
}
function dockercmp() { # Params: SERVER COMMAND
	if isvalidserver "${1}"; then
		docker-compose -f docker-compose.yml -p ${PROJECT_NAME}_${1} --project-directory ${SERVERS_BASEDIR}/${1} ${@:2}
	fi
}
function dockercmp_all() { # Params: COMMAND
	for dir in ${SERVERS_BASEDIR}/*; do
		if isvalidserver "$(basename ${dir})"; then
			dockercmp "$(basename ${dir})" ${@:1}
		fi
	done
}

echo -e "${COLOR_CYAN}${COLOR_BOLD}===   ${ARKSERVERCONTROL_NAME} v${ARKSERVERCONTROL_VERSION}; Project: ${COLOR_RED}${PROJECT_NAME}${COLOR_CYAN};   ===${COLOR_RESET}\n"

if [ "${1}" == "--help" ] || [ -z "${1}" ]; then
	echo "${COLOR_WHITE}${COLOR_BOLD}${0} [--help|list|[all|<Servername>] <docker-compose command>]${COLOR_RESET}"
elif [ "${1}" == "list" ]; then
	echo "${COLOR_WHITE}${COLOR_BOLD}List of all Servers:${COLOR_RESET}"
	for dir in ${SERVERS_BASEDIR}/*; do
		if isvalidserver "$(basename ${dir})"; then
			echo "${COLOR_WHITE}${COLOR_BOLD}  - ${COLOR_BLUE}$(basename $dir)${COLOR_RESET}"
		fi
	done
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
