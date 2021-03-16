#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly usage_config_msg_short="
Usage:
  dbm config <dev|prod> <output> [flags]
"

readonly usage_config_msg_full="
Config generates a consolidated Docker Compose file for the targeted environment
and writes the output to a specified file.

${usage_config_msg_short}

Examples:
  dbm config dev output.yml
  Generate output.yml using docker-compose.yml and docker-compose.dev.yml

  dbm config prod output.yml
  Generate output.yml using docker-compose.yml and docker-compose.prod.yml

Global Flags:
  -h, --help                  Help for the config command

"


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Generate a Docker Compose file.
#=======================================================================================================================
# Arguments:
#   $1 - Generated temporary Docker Compose file.
#   $2 - Output file.
# Outputs:
#   Docker Compose file.
#=======================================================================================================================
execute_config() {
    print_status "Generating Docker Compose file"
    temp_file="$1"
    output_file="$2"

    # Verify the input file exists
    if [ ! -f "${temp_file}" ]; then
        echo "Cannot find temporary Docker Compose file: ${temp_file}"
        return 1
    fi

    # Warn if output file exists
    if [ -f "${output_file}" ]; then
        echo
        echo "WARNING! The file '${output_file}' will be overwritten"
        echo
        confirm_operation || return 1
    fi

    # Make a copy from the temp file
    cp "${temp_file}" "${output_file}"
    
    log "Generated '${output_file}'"
    return 0
}

#=======================================================================================================================
# Parse and validate the command-line arguments for the config command.
#=======================================================================================================================
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, returns 1 on fatal error.
#=======================================================================================================================
parse_config_args() {
    error=''
    show_help='false'

    # Ignore first argument, which is the 'config' command
    shift

    # Capture any additional flags
    while [ -n "$1" ] && [ -z "${error}" ] ; do
        case "$1" in
            dev | prod )   arg_target="$1";;
            -h | --help )  show_help='true';;
            *           )  [ -z "${arg_config_file}" ] && arg_config_file="$1" || \
                            error="Argument not supported: $1"
        esac
        [ -n "$1" ] && shift
    done

    [ "${show_help}" = 'true' ] && usage_config 'false' && return 1
    [ -z "${arg_target}" ] && error="Expected target" && arg_config_file=''
    [ -z "${arg_config_file}" ] && [ -z "${error}" ] && error="Expected output file"
    [ -n "${error}" ] && usage_config 'true' && err "${error}" && return 1
    return 0
}

#=======================================================================================================================
# Display usage message for the check command.
#=======================================================================================================================
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
# TODO: check SERVICE support
usage_config() {
    short="$1"
    [ "${short}" = 'true' ] && echo "${usage_config_msg_short}" || echo "${usage_config_msg_full}"
}