#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'lib/docker.sh'
    Include lib/config.sh
    Include lib/compose.sh
    Include lib/docker.sh
    Include lib/log.sh
    Include lib/settings.sh
    Include lib/utils.sh
    Include lib/yaml.sh
    Include cmd/root.sh
    Include cmd/version.sh

    # shellcheck disable=SC2034
    setup() { 
        app_basedir=$(get_absolute_path "${PWD}")
        arg_config='test/dbm.ini'
        arg_target='dev'
        init_global_settings
        prepare_environment

        spec_xbuild_expected="*pushing manifest for docker.io/markdumay/dbm-test:${BUILD_VERSION}-debug * done*"
    }

    # shellcheck disable=SC2154
    cleanup() {
        # Clean up temporary files
        if [ -n "${app_compose_file}" ] && [ -f "${app_compose_file}" ]; then
            rm -f "${app_compose_file}" || true
        fi
    }

    BeforeAll 'setup'
    AfterAll 'cleanup'

    Todo 'bring_container_down()'
    Todo 'bring_container_up()'
    Todo 'build_cross_platform_image()'

    Describe 'build_cross_platform_image()' test
        Parameters
            # shellcheck disable=SC2154
            "${app_compose_file}" ''         'false' "${app_host_os}/${app_host_arch}" "${spec_xbuild_expected}" success
            "${app_compose_file}" ''         'true'  "${app_host_os}/${app_host_arch}" "${spec_xbuild_expected}" success
            "${app_compose_file}" 'dbm-test' 'false' "${app_host_os}/${app_host_arch}" "${spec_xbuild_expected}" success
            "${app_compose_file}" 'invalid'  'false' "${app_host_os}/${app_host_arch}" 'error: failed to find target invalid' failure
        End

        It 'builds a cross-platform development image'
            When call build_cross_platform_image "$1" "$2" "$3" "$4"
            The status should be "$6"
            The error should match pattern "$5"
        End
    End

    Describe 'build_image()' test
        Parameters
            "${app_compose_file}" ''         'false' 'Successfully built' 'alpine-test uses an image, skipping?Building dbm-test*' success
            "${app_compose_file}" ''         'true'  'Successfully built' 'alpine-test uses an image, skipping?Building dbm-test*' success
            "${app_compose_file}" 'dbm-test' 'false' 'Successfully built' 'Building dbm-test*' success
            "${app_compose_file}" 'invalid'  'false' ''                   'No such service: invalid' failure
        End

        It 'builds a regular development image'
            When call build_image "$1" "$2" "$3"
            The status should be "$6"
            The output should start with "$4"
            The error should match pattern "$5"
        End
    End


    Todo 'deploy_stack()'
    Todo 'get_arch()'
    Todo 'get_os()'
    Todo 'push_image()'
    Todo 'stop_container()'
    Todo 'validate_platforms()'
End