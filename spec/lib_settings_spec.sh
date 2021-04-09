#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'lib/settings.sh' settings
    Include lib/config.sh
    Include lib/compose.sh
    Include lib/docker.sh
    Include lib/log.sh
    Include lib/repository.sh
    Include lib/settings.sh
    Include lib/utils.sh
    Include lib/yaml.sh
    Include cmd/root.sh

    # shellcheck disable=SC2034
    setup() { 
        set_log_color 'false'
        app_basedir=$(get_absolute_path "${PWD}")
        app_sourcedir="${app_basedir}"
        arg_config='test/dbm.ini'
        arg_target='dev'
    }

    # shellcheck disable=SC2154
    cleanup() {
        if [ -n "${app_compose_file}" ] && [ -f "${app_compose_file}" ]; then
            rm -f "${app_compose_file}" || true
        fi
    }

    BeforeAll 'setup'
    AfterAll 'cleanup'

    Describe 'init_global_settings()' docker
        conditions() { [ "${SHELLSPEC_SKIP_DOCKER}" = 'true' ] && echo "skip"; }
        Skip if 'function returns "skip"' [ "$(conditions)" = "skip" ]

        init_script_version() { echo 'version'; }
        get_os() { echo 'os'; }
        get_arch() { echo 'arch'; }

        It 'initializes global settings'
            When call init_global_settings
            The status should be success
            The variable app_script_version should equal 'version'
            The variable app_host_os should equal 'os'
            The variable app_host_arch should equal 'arch'
            The variable app_docker_compose_flags should equal '-f test/docker-compose.yml -f test/docker-compose.dev.yml'
            The variable arg_platforms should equal ''
            The variable arg_detached should equal 'false'
        End
    End

    Describe 'init_script_version()'
        setup_local() {
            temp_file=$(mktemp -t "dbm.version.XXXXXXXXX")
            version_file=$(dirname "${temp_file}")
            version_file="${version_file}/VERSION"
            echo 'version' > "${version_file}"
        }

        cleanup_local() {
            { [ -f "${temp_file}" ] && rm -rf "temp_file"; } || true
            { [ -f "${version_file}" ] && rm -rf "version_file"; } || true
        }

        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            "$(dirname "${version_file}")" 'version' success
            "$(uuidgen)" 'unknown' success
        End

        It 'initializes the script version'
            When call init_script_version "$1"
            The status should be success
            The output should equal "$2"
        End
    End

    Describe 'prepare_environment()' docker
        conditions() { [ "${SHELLSPEC_SKIP_DOCKER}" = 'true' ] && echo "skip"; }
        Skip if 'function returns "skip"' [ "$(conditions)" = "skip" ]

        setup_local() { 
            init_global_settings || { err "Cannot init settings"; return 1; }
        }

        # shellcheck disable=SC2154
        cleanup_local() {
            if [ -n "${app_compose_file}" ] && [ -f "${app_compose_file}" ]; then
                rm -f "${app_compose_file}" || true
            fi
        }

        expected_vars() { %text
            #|export ALPINE_DIGEST=sha256:a75afd8b57e7f34e4dad8d65e2c7ba2e1975c795ce1ee22fa34f8cf46f96a3be
            #|export ALPINE_VERSION=3.13.2
            #|export BUILD_GID=1001
            #|export BUILD_UID=1001
            #|export BUILD_VERSION=0.1.0
            #|export IMAGE_SUFFIX=-debug
        }

        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        It 'prepares the environment'
            When call prepare_environment
            The status should be success
            The variable app_compose_file should match pattern '*dbm_temp*'
            The variable app_exported_vars should equal "$(expected_vars)"
            The variable app_images should match pattern 'alpine@sha256:*markdumay/dbm-test:0.1.0-debug'
        End
    End

    Describe 'stage_env()'
        setup_local() { 
            init_global_settings || { err "Cannot init settings"; return 1; }
        }

        # shellcheck disable=SC2154
        cleanup_local() {
            if [ -n "${app_compose_file}" ] && [ -f "${app_compose_file}" ]; then
                rm -f "${app_compose_file}" || true
            fi
        }

        expected_vars() { %text
            #|export ALPINE_DIGEST=sha256:a75afd8b57e7f34e4dad8d65e2c7ba2e1975c795ce1ee22fa34f8cf46f96a3be
            #|export ALPINE_VERSION=3.13.2
            #|export BUILD_GID=1001
            #|export BUILD_UID=1001
            #|export BUILD_VERSION=0.1.0
            #|export IMAGE_SUFFIX=
        }

        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            'dev' "$(expected_vars)-debug" success
            'prod' "$(expected_vars)" success
        End

        It 'stages the environment variables'
            When call stage_env "$1"
            The status should be "$3"
            The output should eq "$2"
        End
    End

    Describe 'validate_host_dependencies()' docker
        conditions() { [ "${SHELLSPEC_SKIP_DOCKER}" = 'true' ] && echo "skip"; }
        Skip if 'function returns "skip"' [ "$(conditions)" = "skip" ]

        validate_dependencies() { echo "$1"; return 0; }
        validate_platforms() { return 0; }

        Parameters
            build     "${CORE_DEPENDENCIES}"                             success
            check     "${CORE_DEPENDENCIES} ${REPOSITORY_DEPENDENCIES}"  success
            deploy    "${CORE_DEPENDENCIES}"                             success
            down      "${CORE_DEPENDENCIES}"                             success
            generate  "${CORE_DEPENDENCIES}"                             success
            info      ''                                                 success
            remove    "${CORE_DEPENDENCIES}"                             success
            sign      "${CORE_DEPENDENCIES}"                             success
            stop      "${CORE_DEPENDENCIES}"                             success
            trust     "${TRUST_DEPENDENCIES}"                            success
            up        "${CORE_DEPENDENCIES}"                             success
            version   "${VERSION_DEPENDENCIES}"                          success
        End

        It 'validates the correct host dependencies'
            When call validate_host_dependencies "$1"
            The status should be "$3"
            The output should eq "$2"
        End
    End
End