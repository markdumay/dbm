#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly usage_down_msg_short="
Usage:
  dbm stop <dev|prod> [flags] [service...]
"

readonly usage_down_msg_full="
Down stops the execution of running Docker containers for the targeted
environment. Once stopped, the container and related networks are
removed. The referenced image(s) are untouched. It does not stop or
remove deployed Docker Stack services.

${usage_down_msg_short}

Examples:
  dbm down dev
  Stops and removes all containers and networks associated with the
  development environment
 
  dbm down prod myservice
  Stops and removes the container and network(s) identified by
  'myservice' associated with the production environment
 
Global Flags:
      --config <file>         Config file to use (defaults to dbm.ini)
      --no-digest             Skip validation of digests
  -h, --help                  Help for the stop command

"


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Stop a running container and remove defined containers/networks.
#=======================================================================================================================
# Arguments:
#   $1 - Docker Compose configuration file
#   $2 - Services
# Outputs:
#   Removed Docker container(s) and network(s), terminates on error.
#=======================================================================================================================
execute_down() {
    compose_file="$1"
    services="$2"

    print_status "Bringing containers and networks down"
    bring_container_down "${compose_file}" "${services}" && return 0 || return 1
}

#=======================================================================================================================
# Parse and validate the command-line arguments for the down command.
#=======================================================================================================================
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, returns 1 on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
parse_down_args() {
    error=''

    # Ignore first argument, which is the 'down' command
    shift

    # Capture any additional flags
    while [ -n "$1" ] && [ -z "${error}" ] ; do
        case "$1" in
            dev | prod )    arg_target="$1";;
            --config )      shift; [ -n "$1" ] && arg_config="$1" || error="Missing config filename";;
            --no-digest )   arg_no_digest='true';;
            --tag       )   shift; [ -n "$1" ] && arg_tag="$1" || error="Missing tag argument";;
            -h | --help )   usage_down 'false'; exit;;
            * )             service=$(parse_service "$1") && arg_services="${arg_services}${service} " || \
                                error="Argument not supported: ${service}"
        esac
        [ -n "$1" ] && shift
    done

    # Remove leading and trailing spaces
    arg_services=$(echo "${arg_services}" | awk '{$1=$1};1') 

    # Validate arguments
    [ -z "${arg_target}" ] && error="Expected target" && arg_services=''
    [ -n "${error}" ] && usage_down 'true' && err "${error}" && return 1
    return 0
}

#=======================================================================================================================
# Display usage message for the down command.
#=======================================================================================================================
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage_down() {
    short="$1"
    [ "${short}" = 'true' ] && echo "${usage_down_msg_short}" || echo "${usage_down_msg_full}"
}