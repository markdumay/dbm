#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly usage_build_msg_short="
Usage:
  dbm build <dev|prod> [flags] [service...]
"

readonly usage_build_msg_full="
Build generates a consolidated Docker Compose file for the targeted environment
and builds the specified image(s). The build target is a mandatory argument and
can be either 'dev' (development) or 'prod' (production). By default, images are
registered locally and support the architecture (CPU and OS) of the host only.

Provide the '--push' and '--platforms' flags to trigger a multi-
architecture build instead of a regular build. The resulting image(s) are pushed
to a central Docker registry (typically docker.io). The build command invokes
Docker buildx, which needs to be enabled on the host (and is currently an
experimental Docker feature).

The images follow the naming scheme defined in the docker-compose.yml files. DBM
sets the BUILD_VERSION and IMAGE_SUFFIX environment variables, which can be used
to parameterize the individual image names. The BUILD_VERSION is retrieved from
the VERSION file in the source repository. IMAGE_SUFFIX is set to '-debug' when
targeting a development environment. Use the '--tag' flag to override this
behavior.

${usage_build_msg_short}

Examples:
  dbm build dev
  Build development image(s) using docker-compose.yml and docker-compose.dev.yml

  dbm build prod --push --platforms linux/amd64,linux/arm64
  Build production image(s) using docker-compose.yml and docker-compose.dev.yml,
  target two platforms, and push the image(s) to the Docker registry.

Flags:
  --no-cache                  Do not use cache when building the image
  --platforms <platforms...>  Targeted multi-architecture platforms
                              (comma separated)
  --push                      Push image to Docker Registry
  --tag <tag>                 Image tag override

Global Flags:
      --config <file>         Config file to use (defaults to dbm.ini)
      --no-digest             Skip validation of digests
  -h, --help                  Help for the build command

"


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Display time elapsed in a user-friendly way. For example:
#   $ display_time 11617: 3 hours 13 minutes and 37 seconds
#   $ display_time 42: 42 seconds
#   $ display_time 662: 11 minutes and 2 seconds
#=======================================================================================================================
# Arguments:
#   $1 - Time in seconds
# Outputs:
#   Writes user-friendly time to stdout if applicable.
#=======================================================================================================================
display_time() {
    t=$1
    d=$((t/60/60/24))
    h=$((t/60/60%24))
    m=$((t/60%60))
    s=$((t%60))
    [ "${d}" -gt 0 ] && printf '%d days ' "${d}"
    [ "${h}" -gt 0 ] && printf '%d hours ' "${h}"
    [ "${m}" -gt 0 ] && printf '%d minutes ' "${m}"
    [ "${d}" -gt 0 ] || [ $h -gt 0 ] || [ $m -gt 0 ] && printf 'and '
    [ "${s}" = 1 ] && printf '%d second' "${s}" || printf '%d seconds' "${s}"
}


#=======================================================================================================================
# Build a Docker image.
#=======================================================================================================================
# Arguments:
#   $1 - Docker Compose configuration file
#   $2 - Services
#   $3 - Images
#   $4 - No cache flag
#   $5 - Push
#   $6 - Docker platforms
# Outputs:
#   New Docker image, terminates on error.
#=======================================================================================================================
execute_build() {
    # init arguments
    compose_file="$1"
    services="$2"
    images="$3"
    no_cache="$4"
    push="$5"
    docker_platforms="$6"

    print_status "Building images"

    # capture the start time of the build
    t1=$(date +%s)

    # init regular build
    if [ -z "${docker_platforms}" ]; then
        log "Initializing regular build"
        build_image "${compose_file}" "${services}" "${no_cache}" || return 1

        # push images to registry if applicable
        if [ "${push}" = 'true' ] && [ -n "${images}" ]; then
            push_image "${images}" || return 1
        fi
    # init multi-architecture build
    else
        log "Initializing multi-architecture build"
        display_platforms=$(echo "${docker_platforms}" | sed 's/,/, /g' )
        log "Targeted platforms: ${display_platforms}"
        build_cross_platform_image "${compose_file}" "${services}" "${no_cache}" "${docker_platforms}" || return 1
    fi

    # display elapsed build time
    t2=$(date +%s)
    elapsed_string=$(display_time $((t2 - t1)))
    [ "${t2}" -gt "${t1}" ] && log "Total build time ${elapsed_string}"
}

#=======================================================================================================================
# Parse and validate the command-line arguments for the build command.
#=======================================================================================================================
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, returns 1 on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
# TODO: add sign flag
parse_build_args() {
    error=''

    # Ignore first argument, which is the 'build' command
    shift

    # Capture any additional flags
    while [ -n "$1" ] && [ -z "${error}" ] ; do
        case "$1" in
            dev | prod )    arg_target="$1";;
            --config )      shift; [ -n "$1" ] && arg_config="$1" || error="Missing config filename";;
            --no-cache )    arg_no_cache='true';;
            --no-digest )   arg_no_digest='true';;
            --platforms )   shift; [ -n "$1" ] && arg_platforms="$1" || error="Missing platform argument";;
            --push )        arg_push='true';;
            --tag )         shift; [ -n "$1" ] && arg_tag="$1" || error="Missing tag argument";;
            -h | --help )   usage_build 'false'; exit;;
            * )             service=$(parse_service "$1") && arg_services="${arg_services}${service} " || \
                                error="Argument not supported: ${service}"
        esac
        [ -n "$1" ] && shift
    done

    # Remove leading and trailing spaces
    arg_services=$(echo "${arg_services}" | awk '{$1=$1};1') 

    # Validate arguments
    [ -z "${arg_target}" ] && error="Expected target" && arg_services=''
    [ "${arg_push}" = 'false' ] && [ -n "${arg_platforms}" ] && [ -z "${error}" ] && \
        error="Add '--push' for multi-architecture build"
    service_count=$(echo "${arg_services}" | wc -w)
    [ -n "${arg_tag}" ] && [ "${service_count}" -gt 1 ] && [ -z "${error}" ] && \
        error="Tag supports one service only"

    [ -n "${error}" ] && usage_build 'true' && err "${error}" && return 1
    return 0
}

#=======================================================================================================================
# Display usage message for the build command.
#=======================================================================================================================
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage_build() {
    short="$1"
    [ "${short}" = 'true' ] && echo "${usage_build_msg_short}" || echo "${usage_build_msg_full}"
}