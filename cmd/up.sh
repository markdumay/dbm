#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly usage_up_msg_short="
Usage:
  dbm up <dev|prod> [flags] [SERVICE...]
"

readonly usage_up_msg_full="
Up initiates and starts the containers for the targeted environment. The
referenced images need to be available either locally or remotely. Build the
images prior to the up operation if needed.

${usage_up_msg_short}

Examples:
  dbm up dev
  Starts all development containers and networks
 
  dbm up prod myservice
  Starts the production container and network(s) identified by 'myservice'
 
Flags:
  -d, --detached              Run in detached mode
  -t, --terminal              Start terminal (if supported by image)
      --shell                 Shell to invoke for terminal (defaults to 'sh')
      --tag <tag>             Image tag override

Global Flags:
      --config <file>         Config file to use (defaults to dbm.ini)
      --no-digest             Skip validation of digests
  -h, --help                  Help for the up command

"


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Run a Docker image as container.
#=======================================================================================================================
# Arguments:
#   $1 - Docker Compose configuration file
#   $2 - Services to bring up
#   $3 - Detached mode (expects 'true' or 'false')
#   $4 - Terminal mode (expects 'true' or 'false')
#   $5 - Shell command (e.g. sh, bash, zsh)
# Outputs:
#   New Docker container, terminates on error.
#=======================================================================================================================
execute_up() {
    compose_file="$1"
    services="$2"
    detached="$3"
    terminal="$4"
    shell="$5"

    print_status "Bringing containers and networks up"
    bring_container_up "${compose_file}" "${services}" "${detached}" "${terminal}" "${shell}" || return 1
}

#=======================================================================================================================
# Parse and validate the command-line arguments for the up command.
#=======================================================================================================================
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, returns 1 on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
parse_up_args() {
    error=''

    # Ignore first argument, which is the 'up' command
    shift

    # Capture any additional flags
    while [ -n "$1" ] && [ -z "${error}" ] ; do
        case "$1" in
            dev | prod )        arg_target="$1";;
            -d | --detached )   arg_detached='true';;
            -t | --terminal )   arg_terminal='true';;
            -h | --help )       usage_up 'false'; exit;;
            --config )          shift; [ -n "$1" ] && arg_config="$1" || error="Missing config filename";;
            --no-digest )       arg_no_digest='true';;
            --shell )           shift; [ -n "$1" ] && arg_shell="$1" || error="Missing shell argument";;
            --tag )             shift; [ -n "$1" ] && arg_tag="$1" || error="Missing tag argument";;
            * )                 service=$(parse_arg "$1") && arg_services="${arg_services}${service} " || \
                                    error="Argument not supported: ${service}"
        esac
        [ -n "$1" ] && shift
    done

    # Remove leading and trailing spaces
    arg_services=$(echo "${arg_services}" | awk '{$1=$1};1') 

    # Validate arguments
    [ -z "${arg_target}" ] && error="Expected target" && arg_services=''
    [ "${arg_detached}" = 'true' ] && [ "${arg_terminal}" = 'true' ] && [ -z "${error}" ] && \
        arg_detached='false' && error="Specify either detached mode or terminal mode"

    service_count=$(echo "${arg_services}" | wc -w)
    [ "${arg_terminal}" = 'true' ] && [ "${service_count}" -gt 1 ] && [ -z "${error}" ] && \
        error="Terminal mode supports one service only"

    [ -n "${error}" ] && usage_up 'true' && err "${error}" && return 1
    return 0
}

#=======================================================================================================================
# Display usage message for the up command.
#=======================================================================================================================
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage_up() {
    short="$1"
    [ "${short}" = 'true' ] && echo "${usage_up_msg_short}" || echo "${usage_up_msg_full}"
}