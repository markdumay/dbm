#!/bin/sh

#=======================================================================================================================
# Title         : dbm.sh
# Description   : Helper script to manage Docker images
# Author        : Mark Dumay
# Date          : March 16th, 2021
# Version       : 0.7.0
# Usage         : ./dbm.sh [OPTIONS] COMMAND
# Repository    : https://github.com/markdumay/dbm.git
# License       : Copyright © 2021 Mark Dumay. All rights reserved.
#                 Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
# Comments      : 
#=======================================================================================================================

#=======================================================================================================================
# Dependencies
#=======================================================================================================================
basedir=$(dirname "$0")
# shellcheck source=lib/config.sh
. "${basedir}"/lib/config.sh
# shellcheck source=lib/compose.sh
. "${basedir}"/lib/compose.sh
# shellcheck source=lib/docker.sh
. "${basedir}"/lib/docker.sh
# shellcheck source=lib/log.sh
. "${basedir}"/lib/log.sh
# shellcheck source=lib/repository.sh
. "${basedir}"/lib/repository.sh
# shellcheck source=lib/utils.sh
. "${basedir}"/lib/utils.sh
# shellcheck source=lib/yaml.sh
. "${basedir}"/lib/yaml.sh
# shellcheck source=cmd/root.sh
. "${basedir}"/cmd/root.sh
# shellcheck source=cmd/build.sh
. "${basedir}"/cmd/build.sh
# shellcheck source=cmd/check.sh
. "${basedir}"/cmd/check.sh
# shellcheck source=cmd/config.sh
. "${basedir}"/cmd/config.sh
# shellcheck source=cmd/deploy.sh
. "${basedir}"/cmd/deploy.sh
# shellcheck source=cmd/down.sh
. "${basedir}"/cmd/down.sh
# shellcheck source=cmd/info.sh
. "${basedir}"/cmd/info.sh
# shellcheck source=cmd/stop.sh
. "${basedir}"/cmd/stop.sh
# shellcheck source=cmd/up.sh
. "${basedir}"/cmd/up.sh
# shellcheck source=cmd/version.sh
. "${basedir}"/cmd/version.sh

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly CORE_DEPENDENCIES='awk cut date docker docker-compose grep sed tr uname wc'
readonly REPOSITORY_DEPENDENCIES='curl jq'
readonly VERSION_DEPENDENCIES='basename cat dirname'
# readonly TRUST_DEPENDENCIES='notary openssl'

images=''
config_file=''

#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Validates if required commands are available on the host, considering the provided command and target platform
# settings.
#=======================================================================================================================
# Arguments:
#   $1 - Main command from the command-line.
#   $2 - Target platforms to test, comma separated.
# Outputs:
#   Returns 0 if valid and returns 1 if invalid.
#=======================================================================================================================
validate_host_dependencies() {
    command="$1"
    platforms="$2"
    host_dependencies="${CORE_DEPENDENCIES}"
    check_daemon='false'
    check_buildx='false'

    # Check if required commands are available
    # TODO: add trust: TRUST_DEPENDENCIES='notary'
    # TODO: verify if daemon is needed for config
    case "${command}" in
        build )                     check_daemon='true'; [ -n "${platforms}" ] && check_buildx='true';;
        deploy | down | stop | up ) check_daemon='true';;
        config )                    ;;
        check )                     host_dependencies="${CORE_DEPENDENCIES} ${REPOSITORY_DEPENDENCIES}";;
        version )                   host_dependencies="${VERSION_DEPENDENCIES}";;
    esac
    validate_dependencies "${host_dependencies}" || return 1

    # Validate Docker daemon is running
    if [ "${check_daemon}" = 'true' ] ; then
        if ! docker info >/dev/null 2>&1; then
            err "Docker daemon not running"
            return 1
        fi
    fi

    # Confirm buildx platforms are supported
    if [ "${check_buildx}" = 'true' ] ; then
        validate_platforms "${platforms}" || return 1
    fi

    return 0
}

#=======================================================================================================================
# Shows information about the host, key binaries, and environment variables.
#=======================================================================================================================
# Arguments:
#   $1 - Script version.
#   $2 - Host OS.
#   $3 - Host CPU architecture.
#   $4 - Exported environment variables, line by line.
# Outputs:
#   Writes version information to stdout.
#=======================================================================================================================
show_host_env() {
    script_version="$1"
    host_os="$2"
    host_arch="$3"
    exported_vars="$4"

    # Show host and environment information
    print_status "Capturing host configuration"
    execute_show_info "${script_version}" "${host_os}" "${host_arch}"
    log "Environment:"    
    log "${exported_vars}"
}

stage_env() {
    command="$1"
    target="$2"
    terminal="$3"
    staged="$4"

    # Validate host dependencies
    validate_host_dependencies "${command}" || return 1

    # Export environment variables
    staged=$(export_env_values)  || return 1
    eval "${staged}"
    BUILD_VERSION=$(cat 'VERSION' 2> /dev/null)
    export BUILD_VERSION
    [ "${target}" = 'dev' ] && export IMAGE_SUFFIX='-debug' 

    # Display environment
    exported_vars=$(echo "${staged}" | sed 's/^export /  /g')
    show_host_env "${script_version}" "${host_os}" "${host_arch}" "${exported_vars}"
    return 0
}

#=======================================================================================================================
# Entrypoint for the script.
#=======================================================================================================================
main() {
    # config_file=''
    result=0

    # Parse command-line arguments
    parse_args "$@"

    # Initialize global settings
    init_config
    script_version=$(init_script_version)
    host_os=$(get_os)
    host_arch=$(get_arch)
    docker_compose_flags="-f ${config_docker_base_yml}"
    [ "${arg_target}" = 'dev' ] && docker_compose_flags="${docker_compose_flags} -f ${config_docker_dev_yml}"
    [ "${arg_target}" = 'prod' ] && docker_compose_flags="${docker_compose_flags} -f ${config_docker_prod_yml}"
    [ "${arg_platforms}" = "${host_os}/${host_arch}" ] && arg_platforms='' # set regular build if target equals host

    # Prepare environment if applicable
    if [ "${arg_command}" != 'check' ] && [ "${arg_command}" != 'info' ] && [ "${arg_command}" != 'version' ]; then
        # Change to working directory
        cd "${config_docker_working_dir}" 2> /dev/null || \
            { echo "Cannot find working directory: ${config_docker_working_dir}"; return 1; }

        # Stage the environment
        stage_env "${arg_command}" "${arg_target}" "${arg_terminal}" "${staged}" || result=1

        # Generate consolidated compose file
        config_file=$(generate_config_file "${docker_compose_flags}" '') || { err "config_file"; return 1; }

        # Display and validate targeted images
        print_status "Identifying targeted images"
        images=$(list_images "${config_file}" "${arg_services}") || { err "${images}"; return 1; }
        count=$(echo "${images}" | wc -l)
        [ "${count}" -gt 1 ] && [ "${terminal}" = 'true' ] && err "Terminal mode supports one service only" && return 1
        echo "${images}"
    fi

    # Execute commands
    if [ "${result}" -eq 0 ]; then
        case "${arg_command}" in
            build)    execute_build "${config_file}" "${arg_services}" "${images}" "${arg_no_cache}" "${arg_push}" "${arg_platforms}" || result=1;;
            check )   execute_check_upgrades && exit || result=1;;
            config)   execute_config "${config_file}" "${arg_config_file}" || result=1;;
            deploy)   execute_deploy "${config_file}" "${config_docker_service}" || result=1;;
            down)     execute_down "${config_file}" "${arg_services}" || result=1;;
            info)     execute_show_info "${script_version}" "${host_os}" "${host_arch}" && exit || result=1;;
            stop)     execute_stop "${config_file}" "${arg_services}" || result=1;;
            up)       execute_up "${config_file}" "${arg_services}" "${arg_detached}" "${arg_terminal}" "${arg_shell}" || result=1;;
            version ) execute_show_version "${script_version}" && exit || result=1;;
        esac
    fi

    # Clean up temporary files and exit
    if [ -n "${config_file}" ] && [ -f "${config_file}" ]; then
        rm -f "${config_file}" || true
    fi
    [ "${result}" -ne 0 ] && exit "${result}"
    echo "Done."
}

${__SOURCED__:+return}
main "$@"