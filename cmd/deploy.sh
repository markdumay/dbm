#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly usage_deploy_msg_short="
Usage:
  dbm deploy <dev|prod> [flags] [service...]
"

readonly usage_deploy_msg_full="
Deploy generates a consolidated Docker Compose file for the targeted environment
and deploys the defined services as a Docker Stack. The referenced images need
to be available either locally or remotely. Build the images prior to the
deploy operation if needed.

${usage_deploy_msg_short}

Examples:
  dbm deploy dev
  Deploy development images as Docker Stack services

  dbm deploy prod
  Deploy production images as Docker Stack services

Global Flags:
  -h, --help                  Help for the deploy command

"


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Deploy a Docker image as Docker Stack service(s).
#=======================================================================================================================
# Arguments:
#   $1 - service name
# Outputs:
#   New Docker Stack service(s), terminates on error.
#=======================================================================================================================
# TODO: check SERVICE support
execute_deploy() {
    compose_file="$1"
    service_name="$2"

    print_status "Deploying Docker Stack services"
    deploy_stack "${compose_file}" "${service_name}" && return 0 || return 1
}

#=======================================================================================================================
# Parse and validate the command-line arguments for the deploy command.
#=======================================================================================================================
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, returns 1 on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
parse_deploy_args() {
    error=''
    show_help='false'

    # Ignore first argument, which is the 'deploy' command
    shift

    # Capture any additional flags
    while [ -n "$1" ] && [ -z "${error}" ] ; do
        case "$1" in
            dev | prod  )   arg_target="$1";;
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
    [ "${show_help}" = 'true' ] && usage_deploy 'false' && return 1
    [ -z "${arg_target}" ] && error="Expected target" && arg_services=''
    [ -n "${error}" ] && usage_deploy 'true' && err "${error}" && return 1
    return 0
}

#=======================================================================================================================
# Display usage message for the deploy command.
#=======================================================================================================================
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage_deploy() {
    short="$1"
    [ "${short}" = 'true' ] && echo "${usage_deploy_msg_short}" || echo "${usage_deploy_msg_full}"
}