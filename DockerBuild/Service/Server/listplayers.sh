#!/bin/bash

: '>>> ADVANCED CONFIG <<<'
CONFIG_FILE="/ARK/Service/Server/commandline.cfg"

: '>>> SCRIPT SETUP <<<'
BINDIR=$(dirname "$(readlink -fn "$0")")
cd "$BINDIR"

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

if [ -f "${CONFIG_FILE}" ]; then
	eval "`. ${CONFIG_FILE}&>/dev/null
	[ -v ARKSERVER_RCONENABLED ] && declare -p ARKSERVER_RCONENABLED 2>/dev/null
	[ -v ARKSERVER_RCONPASSWORD ] && declare -p ARKSERVER_RCONPASSWORD 2>/dev/null
	[ -v ARKSERVER_RCONPORT ] && declare -p ARKSERVER_RCONPORT 2>/dev/null`"
fi

if ([ "${ARKSERVER_RCONENABLED}" != "True" ] && [ "${ARKSERVER_RCONENABLED}" != "true" ] && [ "${ARKSERVER_RCONENABLED}" != true ]) || [ ! -v ARKSERVER_RCONPASSWORD ] || [ ! -v ARKSERVER_RCONPORT ]; then
	echo "${COLOR_RED}${COLOR_BOLD}Error: RCON is not enabled${COLOR_RESET}"
	exit 1
fi

PLAYERS_LIST="$(./listplayers "127.0.0.1:${ARKSERVER_RCONPORT}" "${ARKSERVER_RCONPASSWORD}" "$(([ "${1}" == "--profile-url" ] || [ "${1}" == "--url" ]) && echo "${1}")")"
LAST_EXIT_CODE="${?}"

if [ "${LAST_EXIT_CODE}" -ne 0 ]; then
	echo "${PLAYERS_LIST}"
	echo "${COLOR_RED}${COLOR_BOLD}Error: Failed to retreive player list${COLOR_RESET}"
	exit "${LAST_EXIT_CODE}"
fi

PLAYER_COUNT=0
while read -r line; do
	[ -n "${line}" ] && PLAYER_COUNT=$((${PLAYER_COUNT}+1))
done <<< "${PLAYERS_LIST}"

[ "${PLAYER_COUNT}" -le 0 ] && echo -n "${COLOR_WHITE}" || echo -n "${COLOR_GREEN}"
echo -n "${COLOR_BOLD}${PLAYER_COUNT}${COLOR_WHITE}"
[ "${ARKSERVER_MAXPLAYERS}" -eq "${ARKSERVER_MAXPLAYERS}" ] &>/dev/null && echo -n " / ${ARKSERVER_MAXPLAYERS}"
echo " Players${COLOR_RESET}"

echo "${COLOR_WHITE}${COLOR_BOLD}${PLAYERS_LIST}${COLOR_RESET}"
