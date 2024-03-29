#!/bin/sh

#=======================================================================================================================
# Title         : dbm.sh
# Description   : Helper script to manage Docker images
# Author        : Mark Dumay
# Date          : July 17th, 2021
# Version       : 0.8.3
# Usage         : ./dbm.sh [OPTIONS] COMMAND
# Repository    : https://github.com/markdumay/dbm.git
# License       : Copyright © 2021 Mark Dumay. All rights reserved.
#                 Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================


#=======================================================================================================================
# Application variables
#=======================================================================================================================
app_script_path=$(realpath "$0")
app_sourcedir=$(dirname "${app_script_path}")


#=======================================================================================================================
# Dependencies
#=======================================================================================================================
# shellcheck source=lib/config.sh
. "${app_sourcedir}"/lib/config.sh
# shellcheck source=lib/compose.sh
. "${app_sourcedir}"/lib/compose.sh
# shellcheck source=lib/docker.sh
. "${app_sourcedir}"/lib/docker.sh
# shellcheck source=lib/log.sh
. "${app_sourcedir}"/lib/log.sh
# shellcheck source=lib/repository.sh
. "${app_sourcedir}"/lib/repository.sh
# shellcheck source=lib/settings.sh
. "${app_sourcedir}"/lib/settings.sh
# shellcheck source=lib/utils.sh
. "${app_sourcedir}"/lib/utils.sh
# shellcheck source=lib/yaml.sh
. "${app_sourcedir}"/lib/yaml.sh
# shellcheck source=cmd/root.sh
. "${app_sourcedir}"/cmd/root.sh
# shellcheck source=cmd/build.sh
. "${app_sourcedir}"/cmd/build.sh
# shellcheck source=cmd/check.sh
. "${app_sourcedir}"/cmd/check.sh
# shellcheck source=cmd/generate.sh
. "${app_sourcedir}"/cmd/generate.sh
# shellcheck source=cmd/deploy.sh
. "${app_sourcedir}"/cmd/deploy.sh
# shellcheck source=cmd/down.sh
. "${app_sourcedir}"/cmd/down.sh
# shellcheck source=cmd/info.sh
. "${app_sourcedir}"/cmd/info.sh
# shellcheck source=cmd/remove.sh
. "${app_sourcedir}"/cmd/remove.sh
# shellcheck source=cmd/stop.sh
. "${app_sourcedir}"/cmd/stop.sh
# shellcheck source=cmd/up.sh
. "${app_sourcedir}"/cmd/up.sh
# shellcheck source=cmd/version.sh
. "${app_sourcedir}"/cmd/version.sh


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Main entrypoint for the script.
#=======================================================================================================================
main() {
    result=0

    # Parse command-line arguments
    parse_args "$@"

    # Initialize global settings
    init_global_settings || exit 1

    # Prepare environment if applicable
    if [ "${arg_command}" != 'check' ] && [ "${arg_command}" != 'info' ] && [ "${arg_command}" != 'version' ]; then
        print_status "Preparing environment"
        prepare_environment || exit 1
        
        # Display information about host, environment, and targeted images
        execute_show_info "${app_script_version}" "${app_host_os}" "${app_host_arch}"
        log "Environment:"    
        log "${app_exported_vars}" | sed 's/^export//g'
        log "Images:"
        display_images=$(echo "${app_images}" | sed 's/^/ /')
        log "${display_images}"
    fi

    # Execute commands
    if [ "${result}" -eq 0 ]; then
        case "${arg_command}" in
            build)    execute_build "${app_compose_file}" "${arg_services}" "${app_images}" "${arg_no_cache}" "${arg_push}" "${arg_platforms}" || result=1;;
            check )   execute_check_upgrades && exit || result=1;;
            deploy)   execute_deploy "${app_compose_file}" "${config_docker_service}" || result=1;;
            down)     execute_down "${app_compose_file}" "${arg_services}" || result=1;;
            generate) execute_generate "${app_compose_file}" "${arg_compose_file}" || result=1;;
            info)     execute_show_info "${app_script_version}" "${app_host_os}" "${app_host_arch}" && exit || result=1;;
            remove)   execute_remove "${config_docker_service}" || result=1;;
            stop)     execute_stop "${app_compose_file}" "${arg_services}" || result=1;;
            up)       execute_up "${app_compose_file}" "${arg_services}" "${arg_detached}" "${arg_terminal}" "${arg_shell}" || result=1;;
            version ) execute_show_version "${app_script_version}" && exit || result=1;;
        esac
    fi

    # Clean up temporary files and exit
    if [ -n "${app_compose_file}" ] && [ -f "${app_compose_file}" ]; then
        rm -f "${app_compose_file}" || true
    fi
    [ "${result}" -ne 0 ] && exit "${result}"
    echo "Done."
}

${__SOURCED__:+return} # avoid calling the main function from within shellspec context
app_basedir=$(get_absolute_path "${PWD}")
main "$@"