#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

# shellcheck disable=SC2034
#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly usage_msg_short="
Usage:
  dbm <command> [flags]
"

# TODO: check tag
readonly usage_msg_full="
Docker Build Manager (DBM) is a helper utility to simplify the development of
custom Docker images. It includes versioning support, the definition of
development and production images, and simplified commands to run images in
detached or terminal mode. DBM uses Docker Compose under the hood.

${usage_msg_short}

Commands:
  build                       Build a Docker image
  check                       Check for dependency upgrades
  config                      Generate a merged Docker Compose file
  deploy                      Deploy Docker Stack service(s)
  down                        Stop running container(s) and network(s)
  info                        Display current system information
  stop                        Stop running container(s)
  up                          Run Docker image(s) as container(s)
  version                     Show version information

Global Flags:
  -h, --help                  Help for a command

"


#=======================================================================================================================
# Variables
#=======================================================================================================================
arg_command=''
arg_target=''
arg_config_file=''
arg_detached='false'
arg_no_cache='false'
arg_platforms=''
arg_push='false'
arg_tag=''
arg_terminal='false'
arg_services=''
arg_shell='sh'


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Parse and validate the command-line arguments for a single service.
#=======================================================================================================================
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, returns 1 on fatal error.
#=======================================================================================================================
parse_service() {
    # Validate and capture the service specification
    prefix=$(echo "$1" | cut -c1)
    [ "${prefix}" = "-" ] && return 1
    echo "$1" && return 0
}

#=======================================================================================================================
# Parse and validate the command-line arguments.
#=======================================================================================================================
# Globals:
#   - command
#   - detached
#   - services
#   - subcommand
#   - terminal
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
parse_args() {
    [ -z "$1" ] && usage && exit 1

    # Process and validate main commands
    case "$1" in
        build )        arg_command="$1"; parse_build_args "$@" || exit 1;;
        check )        arg_command="$1"; parse_check_args "$@" || exit 1;;
        config )       arg_command="$1"; parse_config_args "$@" || exit 1;;
        deploy )       arg_command="$1"; parse_deploy_args "$@" || exit 1;;
        down )         arg_command="$1"; parse_down_args "$@" || exit 1;;
        info )         arg_command="$1"; parse_info_args "$@" || exit 1;;
        stop )         arg_command="$1"; parse_stop_args "$@" || exit 1;;
        up )           arg_command="$1"; parse_up_args "$@" || exit 1;;
        version )      arg_command="$1"; parse_version_args "$@" || exit 1;;
        -h | --help )  usage 'false' && exit 1;;
        * )            usage 'true' && fail "Command not supported: $1"
    esac
}

#=======================================================================================================================
# Display usage message.
#=======================================================================================================================
# Globals:
#   - backup_dir
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage() { 
    short="$1"
    [ "${short}" = 'true' ] && echo "${usage_msg_short}" || echo "${usage_msg_full}"
}