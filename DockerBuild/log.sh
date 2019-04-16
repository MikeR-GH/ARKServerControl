#!/bin/bash

LOG_DIRECTORY="/ARK/Server/StartupLogs"
LOG_FILE_POINT="/ARK/log_file"

BINDIR=$(dirname "$(readlink -fn "$0")")
cd "$BINDIR"

function log_getfile() { # Params: RETURN
	if [ -n "${1}" ]; then
		local logfile_return="";
		if [ -f "${LOG_FILE_POINT}" ]; then
			read -r logfile<${LOG_FILE_POINT}
			if [ -n "${logfile}" ]; then
				logfile_return="${logfile}"
			fi
			unset -v logfile
		fi

		eval "${1}=\"${logfile_return}\""
		unset -v logfile_return
	fi
}

function log_init() { # Params:
	echo "$(date +'%Y-%m-%d_%H-%M-%S').log">${LOG_FILE_POINT}
}

function log_close() {
	if [ -f "${LOG_FILE_POINT}" ]; then
		rm ${LOG_FILE_POINT}
	fi
}

function log_isinit() { # Params:
	return $([ -n "$(log_getfile RET; echo ${RET})" ])
}

function log_append() { # Params: MESSAGE
	if [ -n "${1}" ] && log_isinit; then
		echo "$(date +'%Y-%m-%d_%H-%M-%S')  ||  ${1}">>${LOG_DIRECTORY}/$(log_getfile RET; echo "${RET}")
	fi
}

case "${1}" in
	init)
		: ' Initialize Log '
		if log_isinit; then
			echo "Log is already initialized."
			exit 1
		fi

		log_init
		echo "Log initialized"
	;;
	reinit)
		: ' Reinitialize Log '
		if log_isinit; then
			log_close
		fi
		if log_isinit; then
			echo "Failed to close Log for reinitialization"
			exit 1
		fi

		log_init
		echo "Log reinitialized"
	;;
	close)
		: ' Close Log '

		if ! log_isinit; then
			echo "Log has not been initialized yet."
			exit 1
		fi

		log_close
		echo "Log closed"
	;;
	append)
		: ' Append a string to the initialized log '

		if ! log_isinit; then
			echo "Log has not been initialized yet."
			exit 1
		fi

		if [ -n "${2}" ]; then
			log_append "${2}"
			echo "${2}"
		fi
	;;
	*)
		echo "Use: ${0} {init|reinit|close|append}"
	;;
esac

exit 0
