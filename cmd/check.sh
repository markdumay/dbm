#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly usage_check_msg_short="
Usage:
  dbm check [flags]
"

readonly usage_check_msg_full="
Check validates if any upgrades are available for the dependencies defined in
the dbm.ini file, if both the source repository and version are specified.
Currently supported source repositories are 'hub.docker.com' and 'github.com'.
The version string needs to adhere to semantic versioning standards, with
MAJOR.MINOR as required fields and PATCH optional. The prefix 'v' is also
optional.

${usage_check_msg_short}

Examples:
  dbm check
  Check for dependency upgrades and display the findings

Global Flags:
      --config <file>         Config file to use (defaults to dbm.ini)
  -h, --help                  Help for the check command

"


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Scans all dependencies identified by 'DBM_*_VERSION' in the default config file for potential version upgrades. See 
# lib/repository.sh/check_upgrades() for more details.
#=======================================================================================================================
# Outputs:
#   Writes matching key/value pairs to stdout. Returns 1 in case of potential updates, 0 otherwise.
#=======================================================================================================================
# shellcheck disable=SC2059
execute_check_upgrades() {
    dependencies=$(read_dependencies) || return 1
    check_upgrades "${dependencies}" || return 1
}

#=======================================================================================================================
# Parse and validate the command-line arguments for the check command.
#=======================================================================================================================
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, returns 1 on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
parse_check_args() {
    error=''
    
    # Ignore first argument, which is the 'check' command
    shift 
    
    # Capture any additional flags
    while [ -n "$1" ]; do
        case "$1" in
            --config )    shift; [ -n "$1" ] && arg_config="$1" || error="Missing config filename";;
            -h | --help ) usage_check 'false'; exit;;
            * )           error="Argument not supported: $1"
        esac
        shift
    done

    [ -n "${error}" ] && usage_check 'true' && err "${error}" && return 1
    return 0
}

#=======================================================================================================================
# Display usage message for the check command.
#=======================================================================================================================
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage_check() {
    short="$1"
    [ "${short}" = 'true' ] && echo "${usage_check_msg_short}" || echo "${usage_check_msg_full}"
}