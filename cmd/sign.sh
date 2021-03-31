#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly usage_sign_msg_short="
Usage:
  dbm sign <dev|prod> [flags] [service...]
"

readonly usage_sign_msg_full="
Sign the current images for the targeted environment. An authorized signer or
delegate needs to be available in the local Docker Content Trust store. The
operation prompts for the passphrase of the signer, unless the environment
variable DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE is set.

${usage_sign_msg_short}

Examples:
  dbm sign dev
  Sign the images associated with the development environment.
 
  dbm sign prod myservice
  Sign the myservice production image.

Flags:
  --tag <tag>                 Image tag override

Global Flags:
      --config <file>         Config file to use (defaults to dbm.ini)
      --no-digest             Skip validation of digests
  -h, --help                  Help for the sign command

"


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Sign an image.
#=======================================================================================================================
# Arguments:
#   $1 - Images to be signed
# Outputs:
#   Signed Docker images, terminates on error.
#=======================================================================================================================
execute_sign() {
    images="$1"

    print_status "Signing images"
    sign_image "${images}" '' && return 0 || return 1
}

#=======================================================================================================================
# Parse and validate the command-line arguments for the sign command.
#=======================================================================================================================
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, returns 1 on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
parse_sign_args() {
    error=''

    # Ignore first argument, which is the 'sign' command
    shift

    # Capture any additional flags
    while [ -n "$1" ] && [ -z "${error}" ] ; do
        case "$1" in
            dev | prod )    arg_target="$1";;
            --config )      shift; [ -n "$1" ] && arg_config="$1" || error="Missing config filename";;
            --no-digest )   arg_no_digest='true';;
            --tag       )   shift; [ -n "$1" ] && arg_tag="$1" || error="Missing tag argument";;
            -h | --help )   usage_sign 'false'; exit;;
            * )             service=$(parse_service "$1") && arg_services="${arg_services}${service} " || \
                                error="Argument not supported: ${service}"
        esac
        [ -n "$1" ] && shift
    done

    # Remove leading and trailing spaces
    arg_services=$(echo "${arg_services}" | awk '{$1=$1};1') 

    # Validate arguments
    [ -z "${arg_target}" ] && error="Expected target" && arg_services=''
    [ -n "${error}" ] && usage_sign 'true' && err "${error}" && return 1
    return 0
}

#=======================================================================================================================
# Display usage message for the sign command.
#=======================================================================================================================
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage_sign() {
    short="$1"
    [ "${short}" = 'true' ] && echo "${usage_sign_msg_short}" || echo "${usage_sign_msg_full}"
}