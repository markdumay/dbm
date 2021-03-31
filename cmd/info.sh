#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly usage_info_msg_short="
Usage:
  dbm info [flags]
"

readonly usage_info_msg_full="
Info displays the current system information.
 
${usage_info_msg_short}

Global Flags:
      --config <file>         Config file to use (defaults to dbm.ini)
      --no-digest             Skip validation of digests
  -h, --help                  Help for the info command

"


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Display info information.
#=======================================================================================================================
# Arguments:
#   $1 - Script version, without 'v' prefix
#   $2 - Host OS.
#   $3 - Host CPU architecture.
# Outputs:
#   Writes info information to stdout.
#=======================================================================================================================
execute_show_info() {
    script_version="$1"
    host_os="$2"
    host_arch="$3"

    # Detect current verions of Docker, Docker Compose, and Notary client
    docker_version=$(docker -v 2>/dev/null | grep -Eo "[0-9]*.[0-9]*.[0-9]*," | cut -d',' -f 1)
    compose_version=$(docker-compose -v 2>/dev/null | grep -Eo "[0-9]*.[0-9]*.[0-9]*," | cut -d',' -f 1)
    notary_version=$(notary version 2>/dev/null | grep 'Version:' | awk -F':' '{print $2}' | awk '{$1=$1};1')
    [ -z "${docker_version}" ] && docker_version='N/A' || docker_version="v${docker_version}"
    [ -z "${compose_version}" ] && compose_version='N/A' || compose_version="v${compose_version}"
    [ -z "${notary_version}" ] && notary_version='N/A' || notary_version="v${notary_version}"
    [ -z "${script_version}" ] && script_version='N/A' || script_version="v${script_version}"

    # Show host information
    log "Host:"
    log " Docker Engine: ${docker_version}"
    log " Docker Compose: ${compose_version}"
    log " Docker Build Manager: ${script_version}"
    log " Notary Client: ${notary_version}"
    log " Platform: ${host_os}/${host_arch}"
}

#=======================================================================================================================
# Parse and validate the command-line arguments for the info command.
#=======================================================================================================================
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, returns 1 on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
parse_info_args() {
    error=''
    show_help='false'

    # Ignore first argument, which is the 'info' command
    shift 
    
    # Capture any additional flags
    while [ -n "$1" ] && [ -z "${error}" ] ; do
        case "$1" in
            --config )     shift; [ -n "$1" ] && arg_config="$1" || error="Missing config filename";;
            --no-digest )  arg_no_digest='true';;
            -h | --help )  usage_info 'false'; exit;;
            * )            error="Argument not supported: $1"
        esac
        [ -n "$1" ] && shift
    done

    [ -n "${error}" ] && usage_info 'true' && err "${error}" && return 1
    return 0
}

#=======================================================================================================================
# Display usage message for the info command.
#=======================================================================================================================
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage_info() {
    short="$1"
    [ "${short}" = 'true' ] && echo "${usage_info_msg_short}" || echo "${usage_info_msg_full}"
}