#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly usage_stop_msg_short="
Usage:
  dbm stop <dev|prod> [flags] [service...]
"

readonly usage_stop_msg_full="
Stop pauses the execution of running Docker containers for the targeted
environment. It does not stop or remove deployed Docker Stack services.

${usage_stop_msg_short}

Examples:
  dbm stop dev
  Stops all containers associated with the development environment
 
  dbm stop prod myservice
  Stops the production container identified by 'myservice'
 
Global Flags:
  -h, --help                  Help for the stop command

"


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Stop a running container.
#=======================================================================================================================
# Arguments:
#   $1 - Docker Compose configuration file
#   $2 - Services
# Outputs:
#   Stopped Docker container, terminates on error.
#=======================================================================================================================
execute_stop() {
    compose_file="$1"
    services="$2"

    print_status "Stopping containers and networks"
    stop_container "${compose_file}" "${services}" && return 0 || return 1
}


#=======================================================================================================================
# Parse and validate the command-line arguments for the stop command.
#=======================================================================================================================
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, returns 1 on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
parse_stop_args() {
    error=''
    show_help='false'

    # Ignore first argument, which is the 'stop' command
    shift

    # Capture any additional flags
    while [ -n "$1" ] && [ -z "${error}" ] ; do
        case "$1" in
            dev | prod )    arg_target="$1";;
            -h | --help )   show_help='true';;
            --tag       )   shift; [ -n "$1" ] && arg_tag="$1" || error="Missing tag argument";;
            * )             service=$(parse_service "$1") && arg_services="${arg_services}${service} " || \
                                error="Argument not supported: ${service}"
        esac
        [ -n "$1" ] && shift
    done

    # Remove leading and trailing spaces
    arg_services=$(echo "${arg_services}" | awk '{$1=$1};1') 

    # Validate arguments
    [ "${show_help}" = 'true' ] && usage_stop 'false' && return 1
    [ -z "${arg_target}" ] && error="Expected target" && arg_services=''
    [ -n "${error}" ] && usage_stop 'true' && err "${error}" && return 1
    return 0
}

#=======================================================================================================================
# Display usage message for the deploy command.
#=======================================================================================================================
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage_stop() {
    short="$1"
    [ "${short}" = 'true' ] && echo "${usage_stop_msg_short}" || echo "${usage_stop_msg_full}"
}