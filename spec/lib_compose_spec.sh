#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'lib/compose' compose
    Include lib/config.sh
    Include lib/compose.sh
    Include lib/docker.sh
    Include lib/log.sh
    Include lib/repository.sh
    Include lib/settings.sh
    Include lib/utils.sh
    Include cmd/root.sh

    # shellcheck disable=SC2034
    setup() { 
        echo "PWD: ${PWD}"
        set_log_color 'false'
        app_basedir=$(get_absolute_path "${PWD}")
        echo "BASEDIR: ${app_basedir}"
        arg_config='test/dbm.ini'
        arg_target='dev'

        echo "DEBUG: init_config '${app_basedir}' '${arg_config}'"

        init_global_settings || { err "Cannot init settings"; return 1; }
        # prepare_environment
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

        echo "DOCKER DIR: ${docker_dir}"
        echo "DEBUG: generate_compose_file '${app_docker_compose_flags}' '${docker_dir}' '' '${arg_services}' '${arg_tag}'"


        echo "app_compose_file: ${app_compose_file}"
        echo "app_docker_compose_flags: ${app_docker_compose_flags}"
        echo "app_exported_vars: ${app_exported_vars}"
        echo "app_host_arch: ${app_host_arch}"
        echo "app_host_os: ${app_host_os}"
        echo "app_images: ${app_images}"
        echo "app_script_version: ${app_script_version}"

        echo "arg_command: ${arg_command}"
        echo "arg_target: ${arg_target}"
        echo "arg_config: ${arg_config}"
        echo "arg_compose_file: ${arg_compose_file}"
        echo "arg_detached: ${arg_detached}"
        echo "arg_no_cache: ${arg_no_cache}"
        echo "arg_platforms: ${arg_platforms}"
        echo "arg_push: ${arg_push}"
        echo "arg_tag: ${arg_tag}"
        echo "arg_terminal: ${arg_terminal}"
        echo "arg_services: ${arg_services}"
        echo "arg_shell: ${arg_shell}"

    }

    # shellcheck disable=SC2154
    cleanup() {
        if [ -n "${app_compose_file}" ] && [ -f "${app_compose_file}" ]; then
            rm -f "${app_compose_file}" || true
        fi
    }

    BeforeAll 'setup'
    AfterAll 'cleanup'

    # Todo 'generate_compose_string()'

    Describe 'generate_compose_file()'
        It 'generates a compose file'
            When call generate_compose_file "${app_docker_compose_flags}" "${docker_dir}" '' "${arg_services}" "${arg_tag}"
            The status should be success
            The output should match pattern '*dbm_temp*'
            Dump
            # The error should match pattern '*Stopping dbm-test ... done*'
            # The error should match pattern '*Removing dbm-test ... done*'
        End
    End

    # Todo 'list_images()'
End