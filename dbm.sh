#!/bin/sh

#=======================================================================================================================
# Title         : dbm.sh
# Description   : Helper script to manage Docker images
# Author        : Mark Dumay
# Date          : March 20th, 2021
# Version       : 0.8.0
# Usage         : ./dbm.sh [OPTIONS] COMMAND
# Repository    : https://github.com/markdumay/dbm.git
# License       : Copyright © 2021 Mark Dumay. All rights reserved.
#                 Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
# Comments      : 
#=======================================================================================================================

#=======================================================================================================================
# Dependencies
#=======================================================================================================================
script_path=$(realpath "$0")
basedir=$(dirname "${script_path}")
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
# shellcheck source=cmd/generate.sh
. "${basedir}"/cmd/generate.sh
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
readonly CORE_DEPENDENCIES='awk cut date docker docker-compose grep realpath sed sort tr uname wc'
readonly REPOSITORY_DEPENDENCIES='curl jq'
readonly VERSION_DEPENDENCIES='basename cat dirname'
# readonly TRUST_DEPENDENCIES='notary openssl'


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
# Stages environment variables from both the config file and generated by the script. The variables are exported as a
# shell script using 'export' statements, so the variables can be exported within the caller's context. The script sets
# the following environment variables by default:
#  - BUILD_VERSION: version information retrieved from the VERSION file in the source repository.
#  - IMAGE_SUFFIX: set to '-debug' when targeting a development environment, empty otherwise.
#=======================================================================================================================
# Arguments:
#   $1 - Main command from the command-line.
# Outputs:
#   Returns 0 if valid and returns 1 if invalid.
#=======================================================================================================================
# shellcheck disable=SC2059
stage_env() {
    target="$1"

    # Identify repository version and optional image name suffix
    build_version=$(cat 'VERSION' 2> /dev/null)
    [ "${target}" = 'dev' ] && image_suffix='-debug' 

    # Export environment variables as script
    staged=$(export_env_values) || { echo "${staged}"; return 1; }
    staged="${staged}\nexport BUILD_VERSION=${build_version}"
    staged="${staged}\nexport IMAGE_SUFFIX=${image_suffix}"

    printf "${staged}" | sort
    return 0
}

#=======================================================================================================================
# Main entrypoint for the script.
#=======================================================================================================================
main() {
    result=0
    images=''
    compose_file=''

    # Parse command-line arguments
    parse_args "$@"

    # Initialize global settings
    init_config "${basedir}" "${arg_config}"
    script_version=$(init_script_version)
    host_os=$(get_os)
    host_arch=$(get_arch)
    docker_compose_flags="-f ${config_docker_base_yml}"
    [ "${arg_target}" = 'dev' ] && docker_compose_flags="${docker_compose_flags} -f ${config_docker_dev_yml}"
    [ "${arg_target}" = 'prod' ] && docker_compose_flags="${docker_compose_flags} -f ${config_docker_prod_yml}"
    [ "${arg_platforms}" = "${host_os}/${host_arch}" ] && arg_platforms='' # set regular build if target equals host
    [ "${arg_terminal}" = 'true' ] && arg_detached='true' # always start in daemon mode prior to starting terminal

    # Prepare environment if applicable
    if [ "${arg_command}" != 'check' ] && [ "${arg_command}" != 'info' ] && [ "${arg_command}" != 'version' ]; then
        print_status "Preparing environment"

        # Change to working directory
        {
            docker_dir=$(realpath "${basedir}/${config_docker_working_dir}" 2> /dev/null) &&
            cd "${docker_dir}" 2> /dev/null
         } || { echo "Cannot find working directory: ${docker_dir}"; return 1; }

        # Validate host dependencies
        validate_host_dependencies "${arg_command}" || return 1

        # Stage the environment
        exported_vars=$(stage_env "${arg_target}") || { err "${exported_vars}"; return 1; }
        eval "${exported_vars}"

        # Generate consolidated compose file
        compose_file=$(generate_compose_file "${docker_compose_flags}" "${docker_dir}" '' "${arg_services}" "${arg_tag}") \
            || { err "${compose_file}"; return 1; }

        # Validate targeted images
        images=$(list_images "${compose_file}" "${arg_services}") || { err "${images}"; return 1; }
        count=$(echo "${images}" | wc -l)
        [ "${count}" -gt 1 ] && [ "${terminal}" = 'true' ] && err "Terminal mode supports one service only" && return 1
        [ "${count}" -gt 1 ] && [ -n "${arg_tag}" ] && err "Tag supports one service only" && return 1

        # Display information about host, environment, and targeted images
        execute_show_info "${script_version}" "${host_os}" "${host_arch}"
        log "Environment:"    
        log "${exported_vars}" | sed 's/^export//g'
        log "Targeted images:"
        log "${images}"
    fi

    # Execute commands
    if [ "${result}" -eq 0 ]; then
        case "${arg_command}" in
            build)    execute_build "${compose_file}" "${arg_services}" "${images}" "${arg_no_cache}" "${arg_push}" "${arg_platforms}" || result=1;;
            check )   execute_check_upgrades && exit || result=1;;
            deploy)   execute_deploy "${compose_file}" "${config_docker_service}" || result=1;;
            down)     execute_down "${compose_file}" "${arg_services}" || result=1;;
            generate) execute_generate "${compose_file}" "${arg_compose_file}" || result=1;;
            info)     execute_show_info "${script_version}" "${host_os}" "${host_arch}" && exit || result=1;;
            stop)     execute_stop "${compose_file}" "${arg_services}" || result=1;;
            up)       execute_up "${compose_file}" "${arg_services}" "${arg_detached}" "${arg_terminal}" "${arg_shell}" || result=1;;
            version ) execute_show_version "${script_version}" && exit || result=1;;
        esac
    fi

    # Clean up temporary files and exit
    if [ -n "${compose_file}" ] && [ -f "${compose_file}" ]; then
        rm -f "${compose_file}" || true
    fi
    [ "${result}" -ne 0 ] && exit "${result}"
    echo "Done."
}

${__SOURCED__:+return} # avoid calling the main function from within shellspec context
main "$@"