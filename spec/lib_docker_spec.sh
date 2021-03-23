#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'lib/docker.sh' docker
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
        set_log_color 'false'
        app_basedir=$(get_absolute_path "${PWD}")
        arg_config='test/dbm.ini'
        arg_target='dev'
        init_global_settings
        prepare_environment

        # variable used for xbuild validation
        spec_xbuild_expected="*pushing manifest for docker.io/markdumay/dbm-test:${BUILD_VERSION}-debug * done*"
    }

    # shellcheck disable=SC2154
    cleanup() {
        if [ -n "${app_compose_file}" ] && [ -f "${app_compose_file}" ]; then
            rm -f "${app_compose_file}" || true
        fi
    }

    BeforeAll 'setup'
    AfterAll 'cleanup'

    Describe 'bring_container_down()'
        setup_local() {
            mute 'true'
            build_image "${app_compose_file}" 'dbm-test' 'false'
            bring_container_up "${app_compose_file}" 'dbm-test' 'true' 'false' 'sh'
            mute 'false'
        }

        BeforeCall 'setup_local'

        It 'brings all containers down'
            When call bring_container_down "${app_compose_file}"
            The status should be success
            The error should match pattern '*Stopping dbm-test ... done*'
            The error should match pattern '*Removing dbm-test ... done*'
        End
    End

    Describe 'bring_container_up()'
        setup_local() {
            mute 'true'
            build_image "${app_compose_file}" 'dbm-test' 'false'
            mute 'false'
        }

        cleanup_local() { 
            mute 'true'
            bring_container_down "${app_compose_file}"
            mute 'false'
        }
        
        Before 'setup_local'
        After 'cleanup_local'

        It 'brings a specific container up (detached)'
            When call bring_container_up "${app_compose_file}" 'dbm-test' 'true' 'false' 'sh'
            The status should be success
            The error should match pattern '*Creating dbm-test ... done?'
        End

        It 'brings all containers up (detached)'
            When call bring_container_up "${app_compose_file}" '' 'true' 'false' 'sh'
            The status should be success
            The error should match pattern '*Creating alpine-test ... done*'
            The error should match pattern '*Creating dbm-test    ... done*'
        End
    End

    Describe 'build_cross_platform_image()'
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

    Describe 'build_image()'
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

    Describe 'deploy_stack() and remove_stack()'
        setup_local() {
            mute 'true'
            build_image "${app_compose_file}" 'dbm-test' 'false'
            mute 'false'
        }

        cleanup_local() { 
            mute 'true'
            docker stack rm 'shellspec' || true
            mute 'false'
        }
        
        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        It 'deploys a stack with correct service name'
            When call deploy_stack "${app_compose_file}" 'shellspec'
            The status should be success
            The output should match pattern '*Creating service shellspec_alpine-test*'
            The output should match pattern '*Creating service shellspec_dbm-test*'
            The error should match pattern '*Ignoring unsupported options: build, restart*'
        End

        It 'removes a stack'
            When call remove_stack 'shellspec' 'true'
            The status should be success
            The output should match pattern 'Waiting for Docker Stack to be removed*done'
        End
    End

    Describe 'get_arch()'
        is_valid() {
            is_valid_arch "${is_valid:?}"
        }        

        It 'retrieves a valid architecture'
            When call get_arch
            The status should be success
            The output should satisfy is_valid
        End
    End

    Describe 'get_os()'
        is_valid() {
            is_valid_os "${is_valid:?}"
        }        

        It 'retrieves a valid architecture'
            When call get_os
            The status should be success
            The output should satisfy is_valid
        End
    End

    Describe 'push_image()'
        setup_local() {
            mute 'true'
            build_image "${app_compose_file}" 'dbm-test' 'false'
            mute 'false'
        }

        cleanup_local() { 
            mute 'true'
            bring_container_down "${app_compose_file}"
            mute 'false'
        }
        
        Before 'setup_local'
        After 'cleanup_local'

        Parameters
            "markdumay/dbm-test:${BUILD_VERSION}-debug" "Pushing image to registry" success
            "invalid/invalid" 'WARN:  Cannot push, image not found' failure
        End

        It 'pushes a specific image'
            When call push_image "$1"
            The status should be "$3"
            The output should match pattern "*$2: $1*"
        End
    End

    Describe 'stop_container()'
        setup_local() {
            mute 'true'
            build_image "${app_compose_file}" 'dbm-test' 'false'
            bring_container_up "${app_compose_file}" '' 'true' 'false' 'sh'
            mute 'false'
        }

        cleanup_local() { 
            mute 'true'
            bring_container_down "${app_compose_file}"
            mute 'false'
        }
        
        Before 'setup_local'
        After 'cleanup_local'

        It 'stops a specific container (detached)'
            When call stop_container "${app_compose_file}" 'dbm-test'
            The status should be success
            The error should match pattern '*Stopping dbm-test ... done*'
        End

        It 'stops all containers (detached)'
            When call stop_container "${app_compose_file}" ''
            The status should be success
            The error should match pattern '*Stopping alpine-test ... done*'
            The error should match pattern '*Stopping dbm-test    ... done*'
        End
    End

    Describe 'validate_platforms()'
        Parameters
            "${app_host_os}/${app_host_arch}" '' success
            "invalid/invalid" 'ERROR: Target platforms not supported: invalid/invalid' failure
        End

        It 'correctly validates platforms'
            When call validate_platforms "$1"
            The status should be "$3"
            The error should equal "$2"
        End
    End
End