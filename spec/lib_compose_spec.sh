#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'lib/compose' docker compose
    conditions() { [ "${SHELLSPEC_SKIP_DOCKER}" = 'true' ] && echo "skip"; }
    Skip if 'function returns "skip"' [ "$(conditions)" = "skip" ]

    Include lib/config.sh
    Include lib/compose.sh
    Include lib/docker.sh
    Include lib/log.sh
    Include lib/repository.sh
    Include lib/settings.sh
    Include lib/utils.sh
    Include lib/yaml.sh
    Include cmd/root.sh

    # shellcheck disable=SC2034,SC2154
    setup() { 
        set_log_color 'false'
        app_basedir=$(get_absolute_path "${PWD}")
        app_sourcedir="${app_basedir}"
        arg_config='test/dbm.ini'
        arg_target='dev'

        init_global_settings || { err "Cannot init settings"; return 1; }
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
    }

    # shellcheck disable=SC2154
    cleanup() {
        if [ -n "${app_compose_file}" ] && [ -f "${app_compose_file}" ]; then
            rm -f "${app_compose_file}" || true
        fi
    }

    BeforeAll 'setup'
    AfterAll 'cleanup'

    Describe 'generate_compose_string()'
        It 'generates compose output'
            # shellcheck disable=SC2154
            When call generate_compose_string "${app_docker_compose_flags}" "${docker_dir}" "${arg_tag}"
            The status should be success
            The output should match pattern '*alpine@sha256*test/Dockerfile*'
        End
    End

    Describe 'generate_compose_file()'
        It 'generates a compose file'
            # shellcheck disable=SC2154
            When call generate_compose_file "${app_docker_compose_flags}" "${docker_dir}" '' "${arg_services}" "${arg_tag}"
            The status should be success
            The output should match pattern '*dbm_temp*'
        End
    End

    Describe 'list_images()'
        setup_local() {
            file=$(generate_compose_file "${app_docker_compose_flags}" "${docker_dir}" '' "${arg_services}" "${arg_tag}")
        }

        expected() { %text
            #|alpine@sha256:a75afd8b57e7f34e4dad8d65e2c7ba2e1975c795ce1ee22fa34f8cf46f96a3be
            #|markdumay/dbm-test:0.1.0-debug
        }

        BeforeAll 'setup_local'

        It 'lists docker images'
            When call list_images "${file}"
            The status should be success
            The output should eq "$(expected)"
        End
    End
End