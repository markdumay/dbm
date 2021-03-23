#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

# TODO: handle multi-line messages and/or select last line only

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly RED='\e[31m'   # Red color
readonly GREEN='\e[32m' # Green color
readonly YELLOW='\e[33m' # Yellow color
readonly BLUE='\e[34m' # Blue color
readonly NC='\e[m'      # No color / reset
readonly BOLD='\e[1m'   # Bold font
readonly LOG_DEBUG='DEBUG'
readonly LOG_INFO='INFO'
readonly LOG_WARN='WARN'
readonly LOG_ERROR='ERROR'
readonly LOG_FATAL='FATAL'


#=======================================================================================================================
# Variables
#=======================================================================================================================
log_format='default'
log_prefix=''
log_timestamp=''
log_file_timestamp="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
log_file=''
log_color='true'


#=======================================================================================================================
# Internal Functions
#=======================================================================================================================

#=======================================================================================================================
# Formats a log message using the defined format.
#=======================================================================================================================
# Arguments:
#   $1 - Log format, either default, pretty, or json.
#   $2 - Log timestamp, optional.
#   $3 - Log prefix, added after timestamp, optional.
#   $4 - Log level, either DEBUG, INFO, WARN, ERROR, or FATAL.
#   $5 - Log message.
#   $6 - Log file, optional.
# Outputs:
#   Writes the formatted message to STDOUT, returns 1 if unsuccessful.
#=======================================================================================================================
_msg() {
    format="$1"
    timestamp="$2"
    prefix="$3"
    level="$4"
    msg="$5"
    case "${format}" in 
        default) 
            level=$(echo "${level}" | tr '[:lower:]' '[:upper:]')
            level=$(printf '%-7s' "${level}:")
            [ "${level}" = 'INFO:  ' ] && level=''
            [ -n "${timestamp}" ] && [ -z "${prefix}" ] && prefix=' '
            echo "${timestamp}${prefix}${level}${msg}"
            ;;
        pretty)  
            level=$(echo "${level}" | tr '[:lower:]' '[:upper:]')
            level=$(printf '%-5s' "${level}")
            echo "${timestamp} | ${level} | ${msg}"
            ;;
        json) 
            level=$(echo "${level}" | tr '[:upper:]' '[:lower:]')
            echo "{\"time\":\"${timestamp}\",\"level\":\"${level}\",\"message\":\"${msg}\"}"
            ;;
        * ) return 1
    esac
    
    return 0
}

#=======================================================================================================================
# Log a debug message on the console and append the message to the log file, if defined.
#=======================================================================================================================
# Arguments:
#   $1 - Log level, either DEBUG, INFO, WARN, ERROR, or FATAL.
#   $2 - Log coloring, 'true' (default) or 'false'.
#   $3 - Log message.
#   $4 - Redirect message to STDERR when 'true', defaults to 'STDOUT' ('false').
#   $5 - Add a newline, 'true' (default) or 'false'.
# Outputs:
#   Writes message to STDOUT and optionally appends log file.
#=======================================================================================================================
_show_and_write_log() {
    level="$1"
    color="$2"
    msg="$3"
    redirect="$4"
    formatted=$(_msg "${log_format}" "${log_timestamp}" "${log_prefix}" "${level}" "${msg}") || return 1
    { [ "$5" = 'true' ] || [ -z "$5" ]; } && nl='\n' || nl=''


    # display log message
    if [ "${log_color}" = 'true' ] && [ -n "${color}" ]; then
        if [ "${redirect}" = 'true' ]; then
            >&2 printf "${color}${BOLD}%s${NC}${nl}" "${formatted}"
        else
            printf "${color}${BOLD}%s${NC}${nl}" "${formatted}"
        fi
    else
        if [ "${redirect}" = 'true' ]; then
            >&2 printf "%s${nl}" "${formatted}"
        else
            printf "%s${nl}" "${formatted}"
        fi
    fi

    # append log message to log file if applicable
    if [ -n "${log_file}" ] ; then
        echo "${log_file_timestamp} ${formatted}" >> "${log_file}"
    fi

    return 0
}


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Display a debug message on the console and append the message to the log file, if defined.
#=======================================================================================================================
# Arguments:
#   $1 - Debug message to display.
# Outputs:
#   Writes message to STDOUT and optionally appends log file.
#=======================================================================================================================
debug() {
    msg="$1"
    _show_and_write_log "${LOG_DEBUG}" "${BLUE}" "${msg}" 'false' 'true' && return 0 || return 1
}

#=======================================================================================================================
# Display a message on the console and append the message to the log file, if defined. Unlike info(), it does not add
# coloring to the displayed output.
#=======================================================================================================================
# Arguments:
#   $1 - Log message to display.
# Outputs:
#   Writes message to STDOUT and optionally appends log file.
#=======================================================================================================================
log() {
    msg="$1"
    _show_and_write_log "${LOG_INFO}" '' "${msg}" 'false' 'true' && return 0 || return 1
}

#=======================================================================================================================
# Display a message on the console and append the message to the log file, if defined.
#=======================================================================================================================
# Arguments:
#   $1 - Log message to display.
# Outputs:
#   Writes message to STDOUT and optionally appends log file.
#=======================================================================================================================
info() {
    msg="$1"
    _show_and_write_log "${LOG_INFO}" "${GREEN}" "${msg}" 'false' 'true' && return 0 || return 1
}

#=======================================================================================================================
# Display a message on the console and append the message to the log file, if defined. It does not add a new line.
#=======================================================================================================================
# Arguments:
#   $1 - Log message to display.
# Outputs:
#   Writes message to STDOUT and optionally appends log file.
#=======================================================================================================================
msg() {
    msg="$1"
    _show_and_write_log "${LOG_INFO}" '' "${msg}" 'false' 'false' && return 0 || return 1
}

#=======================================================================================================================
# Display a warning on the console and append the warning to the log file, if defined.
#=======================================================================================================================
# Arguments:
#   $1 - Log message to display.
# Outputs:
#   Writes message to STDOUT and optionally appends log file.
#=======================================================================================================================
warn() {
    msg="$1"
    _show_and_write_log "${LOG_WARN}" "${YELLOW}" "${msg}" 'true' 'true' && return 0 || return 1
}

#=======================================================================================================================
# Display a error on the console and append the error to the log file, if defined.
#=======================================================================================================================
# Arguments:
#   $1 - Log message to display.
# Outputs:
#   Writes message to STDOUT and optionally appends log file.
#=======================================================================================================================
err() {
    msg="$1"
    _show_and_write_log "${LOG_ERROR}" "${RED}" "${msg}" 'true' 'true' && return 0 || return 1
}

#=======================================================================================================================
# Display a fatal error on the console and append the error to the log file, if defined. It exits the program with exit
# code 1.
#=======================================================================================================================
# Arguments:
#   $1 - Log message to display.
# Outputs:
#   Writes message to STDOUT and optionally appends log file, terminates with exit code 1.
#=======================================================================================================================
fail() {
    msg="$1"
    _show_and_write_log "${LOG_ERROR}" "${RED}" "${msg}" 'true' 'true'
    exit 1
}

#=======================================================================================================================
# Display current progress on console.
#=======================================================================================================================
# Arguments:
#   $1 - Progress message to display.
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
print_status() {
    [ "${log_color}" = 'true' ] && printf "${BOLD}%s${NC}\n" "$1" || echo "$1"
}

#=======================================================================================================================
# Sets the logging format. Supported format are:
# - default
#   Default prints logs as standard console output (no timestamp and level prefixes), for example:
#   > Listing snapshots
# - pretty
#   Pretty prints logs as semi-structured messages with a timestamp and level prefix, for example:
#   2020-12-17T07:12:57+01:00 | INFO   | Listing snapshots
# - json
#   JSON prints logs as JSON strings, for example:
#   {"level":"info","time":"2020-12-17T07:12:57+01:00","message":"Listing snapshots"}
#=======================================================================================================================
# Arguments:
#   $1 - Set date and time to UTC, 'true' (default) or 'false'.
#   $2 - Format of the date and time, defaults to '%Y-%m-%dT%H:%M:%SZ' '2016-11-08T08:52:55Z'.
# Outputs:
#   Sets log_timestamp variable.
#=======================================================================================================================
set_log_format() {
    format="$1"
    case "${format}" in 
        default) log_format="${format}";;
        pretty | json) log_format="${format}"; set_timestamp '' '';;
        * ) return 1
    esac

    return 0
}

#=======================================================================================================================
# Sets coloring of STDOUT logs to 'true' or 'false'. 
#=======================================================================================================================
# Arguments:
#   $1 - Log coloring, 'true' (default) or 'false'.
# Outputs:
#   Sets log_color variable.
#=======================================================================================================================
set_log_color() {
    color="$1"
    case "${color}" in
        true) log_color='true';;
        false) log_color='false';;
        * ) return 1
    esac
    return 0
}

#=======================================================================================================================
# Set an optional timestamp as prefix to all log messages. The timestamp defaults to the RFC3339 format. The same format
# is applied as prefix to logs written to a log file, unless it is empty.
#=======================================================================================================================
# Arguments:
#   $1 - Set date and time to UTC, 'true' (default) or 'false'.
#   $2 - Format of the date and time, defaults to '%Y-%m-%dT%H:%M:%SZ' '2016-11-08T08:52:55Z'.
# Outputs:
#   Sets log_timestamp and log_file_timestamp variables.
#=======================================================================================================================
set_timestamp() {
    [ "$1" = 'true' ] && utc='-u ' || utc=''
    [ -n "$2" ] && fmt="$2" || fmt='%Y-%m-%dT%H:%M:%SZ'
    log_timestamp="$(date "${utc}+${fmt}")"

    # set log_file_timestamp equal to file_timestamp, unless empty
    if [ -n "${log_timestamp}" ]; then
        log_file_timestamp="${log_timestamp}"
    else
        log_file_timestamp="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    fi
}