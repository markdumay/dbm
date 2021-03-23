#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly usage_remove_msg_short="
Usage:
  dbm remove <dev|prod> [flags]
"

readonly usage_remove_msg_full="
Remove deletes a previously deployed Docker Stack for the targeted environment.
By convention, all services and networks contained within the stack are
removed (unless referenced externally). The remove commands waits for all
deployed services and networks to be fully removed from the system.

${usage_remove_msg_short}

Examples:
  dbm remove dev
  Remove all development services and networks within the Docker Stack

  dbm remove prod
  Remove all production services and networks within the Docker Stack

Global Flags:
      --config <file>         Config file to use (defaults to dbm.ini)
  -h, --help                  Help for the remove command

"


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Remove a previously deployed Docker Stack. The function waits for all services and networks to be fully removed from
# the system.
#=======================================================================================================================
# Arguments:
#   $2 - Name of the Docker Stack.
# Outputs:
#   Removed Docker Stack, returns 1 on error.
#=======================================================================================================================
execute_remove() {
    service_name="$1"

    print_status "Removing Docker Stack services"
    remove_stack "${service_name}" 'true' && return 0 || return 1
}

#=======================================================================================================================
# Parse and validate the command-line arguments for the remove command.
#=======================================================================================================================
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, returns 1 on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
parse_remove_args() {
    error=''

    # Ignore first argument, which is the 'remove' command
    shift

    # Capture any additional flags
    while [ -n "$1" ] && [ -z "${error}" ] ; do
        case "$1" in
            dev | prod )    arg_target="$1";;
            --config )      shift; [ -n "$1" ] && arg_config="$1" || error="Missing config filename";;
            -h | --help )   usage_remove 'false'; exit;;
            * )             error="Argument not supported: $1"
        esac
        [ -n "$1" ] && shift
    done

    # Validate arguments
    [ -z "${arg_target}" ] && error="Expected target"
    [ -n "${error}" ] && usage_remove 'true' && err "${error}" && return 1
    return 0
}

#=======================================================================================================================
# Display usage message for the remove command.
#=======================================================================================================================
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage_remove() {
    short="$1"
    [ "${short}" = 'true' ] && echo "${usage_remove_msg_short}" || echo "${usage_remove_msg_full}"
}