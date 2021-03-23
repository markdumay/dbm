#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly usage_version_msg_short="
Usage:
  dbm version [flags]
"

readonly usage_version_msg_full="
Version displays the current version of DBM.
 
${usage_version_msg_short}

Global Flags:
      --config <file>         Config file to use (defaults to dbm.ini)
  -h, --help                  Help for the version command

"


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Display script version information.
#=======================================================================================================================
# Arguments:
#   $1 - Script version
# Outputs:
#   Writes version information to stdout.
#=======================================================================================================================
execute_show_version() {
    script_version="$1"
    script=$(basename "$0")
    log "${script} version ${script_version}"
}

#=======================================================================================================================
# Retrieves the version of the Docker Build Manager script.
#=======================================================================================================================
# Outputs:
#   Writes version information to stdout, returns 'unknown' in case of errors.
#=======================================================================================================================
init_script_version() {
    script_dir=$(dirname "$0")
    script_version=$(cat "${script_dir}/VERSION" 2> /dev/null)
    echo "${script_version:-unknown}"
}

#=======================================================================================================================
# Parse and validate the command-line arguments for the version command.
#=======================================================================================================================
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, returns 1 on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
parse_version_args() {
    error=''

    # Ignore first argument, which is the 'version' command
    shift 
    
    # Capture any additional flags
    while [ -n "$1" ] && [ -z "${error}" ] ; do
        case "$1" in
            --config )     shift; [ -n "$1" ] && arg_config="$1" || error="Missing config filename";;
            -h | --help )   usage_version 'false'; exit;;
            * )            error="Argument not supported: $1"
        esac
        shift
    done

    [ -n "${error}" ] && usage_version 'true' && err "${error}" && return 1
    return 0
}

#=======================================================================================================================
# Display usage message for the deploy command.
#=======================================================================================================================
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage_version() {
    short="$1"
    [ "${short}" = 'true' ] && echo "${usage_version_msg_short}" || echo "${usage_version_msg_full}"
}