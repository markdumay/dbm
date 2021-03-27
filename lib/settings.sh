#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly CORE_DEPENDENCIES='awk cut date docker docker-compose grep realpath rev sed sort tr uname wc'
readonly REPOSITORY_DEPENDENCIES='curl jq'
readonly VERSION_DEPENDENCIES='basename cat dirname'
# readonly TRUST_DEPENDENCIES='notary openssl'


#=======================================================================================================================
# Application variables
#=======================================================================================================================
app_compose_file=''
app_docker_compose_flags=''
app_exported_vars=''
app_host_arch=''
app_host_os=''
app_images=''
app_script_version=''

#=======================================================================================================================
# Initialize the global application settings.
#=======================================================================================================================
# Used globals as input:
#   - app_basedir
#   - arg_config
#   - arg_target
#   - arg_terminal
# Set globals:
#   - app_script_version
#   - app_host_os
#   - app_host_arch
#   - app_docker_compose_flags
#   - arg_platforms
#   - arg_detached
# Outputs:
#   Initialized globals.
#=======================================================================================================================
# shellcheck disable=SC2034,SC2154
init_global_settings() {
    init_config "${app_basedir}" "${arg_config}" || { err "Cannot initialize configuration"; return 1; }
    app_script_version=$(init_script_version) || { err "Cannot initialize script version"; return 1; }
    app_host_os=$(get_os)
    app_host_arch=$(get_arch)
    app_docker_compose_flags="-f ${config_docker_base_yml}"
    [ "${arg_target}" = 'dev' ] && app_docker_compose_flags="${app_docker_compose_flags} -f ${config_docker_dev_yml}"
    [ "${arg_target}" = 'prod' ] && app_docker_compose_flags="${app_docker_compose_flags} -f ${config_docker_prod_yml}"
    [ "${arg_platforms}" = "${app_host_os}/${app_host_arch}" ] && arg_platforms='' # set regular build if target equals host
    [ "${arg_terminal}" = 'true' ] && arg_detached='true' # always start in daemon mode prior to starting terminal

    return 0
}

#=======================================================================================================================
# Retrieves the version of the Docker Build Manager script.
#=======================================================================================================================
# Outputs:
#   Writes version information to stdout, returns 'unknown' in case of errors.
#=======================================================================================================================
init_script_version() {
    script_version=$(cat "${app_basedir}/VERSION" 2> /dev/null)
    echo "${script_version:-unknown}"
}

#=======================================================================================================================
# Conducts the following steps to prepare the environment:
#   - Change to working directory: The current directory is set to the working directory specified in the configuration
#     file, relative to the directory of the main DBM script. This is to ensure any relative paths (such as the Docker
#     Compose files and assets for the Dockerfile) can be found.
#   - Validate host dependencies: Pending the given command, DBM checks is required binaries and services are available
#     on the host. For example, the Docker Daemon is expected to be running for all of the following commands: build, 
#     deploy, down, remove, stop, up. See validate_host_dependencies() for the implementation details.
#   - Stage the environment: Exports the environment variables starting with 'DBM_' defined in the configuration file.
#     Typical examples are BUILD_UID, BUILD_GID, BUILD_USER, and BUILD_VERSION.
#   - Generate consolidated compose file: Generates a consolidated Docker Compose file for the targeted platform (dev 
#     or prod). The file is saved to a temporary location.
#   - Validate targeted images: Lists the images defined in the consolidated Docker Compose file. It then validates
#     the settings for terminal mode and tag do not conflict with the configuration.
#=======================================================================================================================
# Used globals as input:
#   - app_basedir
#   - config_docker_working_dir
#   - arg_command
#   - app_docker_compose_flags
#   - arg_services
#   - arg_tag
#   - arg_target
#   - arg_terminal
# Set globals:
#   - app_compose_file
#   - app_exported_vars
#   - app_images
# Outputs:
#   Prepared environment, returns 1 in case of errors.
#=======================================================================================================================
# shellcheck disable=SC2154
prepare_environment() {
    # Change to working directory
    {
        docker_dir=$(realpath "${app_basedir}/${config_docker_working_dir}" 2> /dev/null) &&
        cd "${docker_dir}" 2> /dev/null
        } || { err "Cannot find working directory: ${docker_dir}"; return 1; }

    # Validate host dependencies
    validate_host_dependencies "${arg_command}" || { err "Cannot satisfy host dependencies"; return 1; }

    # Stage the environment
    app_exported_vars=$(stage_env "${arg_target}") || { err "${app_exported_vars}"; return 1; }
    eval "${app_exported_vars}"

    # Generate consolidated compose file
    app_compose_file=$(generate_compose_file "${app_docker_compose_flags}" "${docker_dir}" '' "${arg_services}" "${arg_tag}") \
        || { err "${app_compose_file}"; return 1; }

    # Validate targeted images
    app_images=$(list_images "${app_compose_file}" "${arg_services}") || { err "${app_images}"; return 1; }
    count=$(echo "${app_images}" | wc -l)
    [ "${count}" -gt 1 ] && [ "${arg_terminal}" = 'true' ] && err "Terminal mode supports one service only" && return 1
    [ "${count}" -gt 1 ] && [ -n "${arg_tag}" ] && err "Tag supports one service only" && return 1
    
    return 0
}

#=======================================================================================================================
# Stages environment variables from both the config file and generated by the script. The variables are exported as a
# shell script using 'export' statements, so the variables can be exported within the caller's context. Both the version
# and digest for each dependency is set if available. The function sets the following environment variables by default:
#  - BUILD_VERSION: version information retrieved from the VERSION file in the source repository.
#  - IMAGE_SUFFIX: set to '-debug' when targeting a development environment, empty otherwise.
#=======================================================================================================================
# Arguments:
#   $1 - Build target from the command-line.
# Outputs:
#   Returns 0 if valid and returns 1 if invalid.
#=======================================================================================================================
# shellcheck disable=SC2059,SC2154
stage_env() {
    target="$1"

    # Identify repository version and optional image name suffix
    build_version=$(cat "${config_version_file}" 2> /dev/null) || \
        { err "Cannot find VERSION: ${config_version_file}"; return 1; }
    [ "${target}" = 'dev' ] && image_suffix='-debug' 

    # Export environment variables as script
    if [ "${arg_no_digest}" != 'true' ]; then
        digests=$(export_digest_values) || { digests=''; warn "Could not process all digests"; }
    fi
    staged=$(export_env_values) || { err "${staged}"; return 1; }
    staged="${staged}\nexport BUILD_VERSION=${build_version}"
    staged="${staged}\nexport IMAGE_SUFFIX=${image_suffix}"

    [ -n "${digests}" ] && staged="${digests}\n${staged}"
    printf "${staged}" | sort
    return 0
}

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
        build )                              check_daemon='true'; [ -n "${platforms}" ] && check_buildx='true';;
        deploy | down | remove | stop | up ) check_daemon='true';;
        generate )                           ;;
        check )                              host_dependencies="${CORE_DEPENDENCIES} ${REPOSITORY_DEPENDENCIES}";;
        version )                            host_dependencies="${VERSION_DEPENDENCIES}";;
        * )                    
            # test everything when command is not specified (e.g. unit testing)  
            host_dependencies="${CORE_DEPENDENCIES} ${REPOSITORY_DEPENDENCIES} ${VERSION_DEPENDENCIES}"
            check_daemon='true'
            check_buildx='true'
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
