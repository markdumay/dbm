#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'lib/config.sh' config
    conditions() { [ "${SHELLSPEC_SKIP_DOCKER}" = 'true' ] && echo "skip"; }

    Include lib/config.sh
    Include lib/log.sh
    Include lib/repository.sh
    Include lib/utils.sh

    setup() { set_log_color 'false'; }
    BeforeAll 'setup'

    Describe 'clean_digest_file()'
        input() { %text
            #|github.com/restic/restic v0.12.0 sha:27f241334e9245a212bc2aba4956a5c0392e5940
            #|hub.docker.com/_/alpine v3.13.4 sha256:ec14c7992a97fc11425907e908340c6c3d6ff602f5f13d899e6b7027c9b4133a
            #|hub.docker.com/_/golang v1.16.3 sha256:13457efbeae175217436dbbdb9ba621bd42934a1cddcce2b8b60b99db4e11d12
            #|
        }

        expected() { %text
            #|hub.docker.com/_/alpine v3.13.4 sha256:ec14c7992a97fc11425907e908340c6c3d6ff602f5f13d899e6b7027c9b4133a
            #|
        }

        dependencies() { %text
            #|9:ALPINE hub.docker.com _ alpine 3.13.4;
        }

        setup_local() {
            config_digest_file=$(mktemp -t "dbm.digest.XXXXXXXXX")
            config_digest_file=$(echo "${config_digest_file}" | sed 's|/dbm.digest.XXXXXXXXX.|/dbm.digest.|g') # macOS/mktemp fix
            digests=$(input)
            echo "${digests}" > "${config_digest_file}"
        }

        cleanup_local() {
            { [ -f "${config_digest_file}" ] && rm -rf "config_digest_file"; } || true
        }

        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            "$(dependencies)" "${config_digest_file}" success
        End

        It 'correctly cleans a digest file'
            When call clean_digest_file "$1" "$2"
            The status should be "$3"
            The contents of file "$2" should equal "$(expected)"
        End
    End

    Describe 'export_digest_values()'
        read_stored_digest() { echo "$1" | awk -F'/' '{print $3}'; }

        read_dependencies() { %text
            #|9:ALPINE hub.docker.com _ alpine 3.13.4;10:GOLANG hub.docker.com _ golang 1.16.3;11:RESTIC github.com restic restic 0.12.0;
        }

        expected() { %text
            #|export ALPINE_DIGEST=alpine
            #|export GOLANG_DIGEST=golang
            #|export RESTIC_DIGEST=restic
        }

        Parameters
            "$(expected)" success
        End

        It 'correctly returns dependencies'
            When call export_digest_values
            The status should be "$2"
            The output should eq "$1"
            Dump
        End
    End

    Describe 'export_env_values()'
        input() { %text
            #|DOCKER_WORKING_DIR='./'
            #|DOCKER_BASE_YML='docker-compose.yml'
            #|DOCKER_PROD_YML='docker-compose.prod.yml'
            #|DOCKER_DEV_YML='docker-compose.dev.yml'
            #|DOCKER_SERVICE_NAME='trust'
            #|DBM_BUILD_UID=1001
            #|DBM_BUILD_GID=1001
            #|DBM_ALPINE_VERSION=hub.docker.com/_/alpine 3.13.4 # comment
            #|DBM_GOLANG_VERSION=hub.docker.com/_/golang 1.16.3
            #|DBM_RESTIC_VERSION=github.com/restic/restic 0.12.0
            #|DBM_BASIC_VERSION=1.0
        }

        expected() { %text
            #|export BUILD_UID=1001
            #|export BUILD_GID=1001
            #|export ALPINE_VERSION=3.13.4
            #|export GOLANG_VERSION=1.16.3
            #|export RESTIC_VERSION=0.12.0
            #|export BASIC_VERSION=1.0
        }

        setup_local() {
            config_file=$(mktemp -t "dbm.ini.XXXXXXXXX")
            config_file=$(echo "${config_file}" | sed 's|/dbm.ini.XXXXXXXXX.|/dbm.ini.|g') # macOS/mktemp fix
            config=$(input)
            echo "${config}" > "${config_file}"
        }

        cleanup_local() {
            { [ -f "${config_file}" ] && rm -rf "config_file"; } || true
        }

        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            "$(expected)" success
        End

        It 'correctly exports custom variables'
            When call export_env_values
            The status should be "$2"
            The output should eq "$1"
        End
    End

    Describe 'export_env_values()'
        input() { %text
            #|DBM_INVALID_VERSION=123 456 789
        }

        setup_local() {
            config_file=$(mktemp -t "dbm.ini.XXXXXXXXX")
            config_file=$(echo "${config_file}" | sed 's|/dbm.ini.XXXXXXXXX.|/dbm.ini.|g') # macOS/mktemp fix
            config=$(input)
            echo "${config}" > "${config_file}"
        }

        cleanup_local() {
            { [ -f "${config_file}" ] && rm -rf "config_file"; } || true
        }

        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            'ERROR: Invalid entry in*INVALID_VERSION=123 456 789' failure
        End

        It 'rejects invalid custom variables'
            When call export_env_values
            The status should be "$2"
            The error should match pattern "$1"
        End
    End


    Describe 'get_dependency_name()'
        Parameters
            '9:ALPINE hub.docker.com _ alpine 3.13.2' 'ALPINE' '' success
            '' '' 'ERROR: Cannot read dependency name' failure
        End

        It 'retrieves a dependency name'
            When call get_dependency_name "$1"
            The status should be "$4"
            The output should eq "$2"
            The error should eq "$3"
        End
    End

    Describe 'get_dependency_provider()'
        Parameters
            '9:ALPINE hub.docker.com _ alpine 3.13.2' 'hub.docker.com' '' success
            '9:ALPINE HUB.DOCKER.COM _ alpine 3.13.2' 'hub.docker.com' '' success
            '' '' 'ERROR: Cannot read dependency provider' failure
        End

        It 'retrieves a dependency provider'
            When call get_dependency_provider "$1"
            The status should be "$4"
            The output should eq "$2"
            The error should eq "$3"
        End
    End

    Describe 'get_dependency_owner()'
        Parameters
            '9:ALPINE hub.docker.com _ alpine 3.13.2' '_' '' success
            '' '' 'ERROR: Cannot read dependency owner' failure
        End

        It 'retrieves a dependency owner'
            When call get_dependency_owner "$1"
            The status should be "$4"
            The output should eq "$2"
            The error should eq "$3"
        End
    End

    Describe 'get_dependency_repository()'
        Parameters
            '9:ALPINE hub.docker.com _ alpine 3.13.2' 'alpine' '' success
            '' '' 'ERROR: Cannot read dependency repository' failure
        End

        It 'retrieves a dependency repository'
            When call get_dependency_repository "$1"
            The status should be "$4"
            The output should eq "$2"
            The error should eq "$3"
        End
    End

    Describe 'get_dependency_tag()'
        Parameters
            '9:ALPINE hub.docker.com _ alpine 3.13.2-rc' '3.13.2-rc' '' success
            '' '' 'ERROR: Cannot read dependency tag' failure
        End

        It 'retrieves a dependency tag'
            When call get_dependency_tag "$1"
            The status should be "$4"
            The output should eq "$2"
            The error should eq "$3"
        End
    End

    Describe 'get_dependency_version()'
        Parameters
            '9:ALPINE hub.docker.com _ alpine 3.13.2-rc' '3.13.2' '' success
            '9:ALPINE hub.docker.com _ alpine 3.13' '3.13.0' '' success
            '9:ALPINE hub.docker.com _ alpine V3.13' '3.13.0' '' success
            '9:ALPINE hub.docker.com _ alpine 3' '' 'ERROR: Cannot read dependency version' failure
            '' '' 'ERROR: Cannot read dependency version' failure
        End

        It 'retrieves a dependency version'
            When call get_dependency_version "$1"
            The status should be "$4"
            The output should eq "$2"
            The error should eq "$3"
        End
    End

    Describe 'get_dependency_extension()'
        Parameters
            '9:ALPINE hub.docker.com _ alpine 3.13.2-rc' '-rc' '' success
            '9:ALPINE hub.docker.com _ alpine 3.13' '' '' success
            '9:ALPINE hub.docker.com _ alpine V3.13-ext' '-ext' '' success
            '9:ALPINE hub.docker.com _ alpine extension' 'extension' '' success
            '' '' 'ERROR: Cannot read dependency version extension' failure
        End

        It 'retrieves a dependency extension'
            When call get_dependency_extension "$1"
            The status should be "$4"
            The output should eq "$2"
            The error should eq "$3"
        End
    End

    Describe 'get_normalized_tag()'
        Parameters
            '3.13.0'  '3.13.0' success
            'v3.13'   '3.13.0' success
            'v3.13.0' '3.13.0' success
        End

        It 'normalizes a tag'
            When call get_normalized_tag "$1"
            The status should be "$3"
            The output should eq "$2"
        End
    End

    Describe 'has_dependency_version()'
        input() { %text
            #|9:ALPINE hub.docker.com _ alpine 3.13.0;10:GOLANG hub.docker.com _ golang 1.16.3;11:RESTIC github.com restic restic 0.12.0;
        }

        Parameters
            'hub.docker.com/_/alpine' '3.13.0'  "$(input)" success
            'hub.docker.com/_/alpine' 'v3.13'   "$(input)" success
            'hub.docker.com/_/alpine' 'v3.13.0' "$(input)" success
            'hub.docker.com/_/alpine' '1.1'     "$(input)" failure
        End

        It 'confirms a dependency availability'
            When call has_dependency_version "$1" "$2" "$3"
            The status should be "$4"
        End
    End

    Describe 'init_config()'
        Skip if 'function returns "skip"' [ "$(conditions)" = "skip" ]

        input() { %text
            #|DOCKER_REGISTRY=DOCKER_REGISTRY
            #|DOCKER_WORKING_DIR=DOCKER_WORKING_DIR
            #|DOCKER_BASE_YML=DOCKER_BASE_YML
            #|DOCKER_PROD_YML=DOCKER_PROD_YML
            #|DOCKER_DEV_YML=DOCKER_DEV_YML
            #|DOCKER_SERVICE_NAME=DOCKER_SERVICE_NAME
            #|DOCKER_TARGET_PLATFORM=DOCKER_TARGET_PLATFORM
        }

        setup_local() {
            config_file=$(mktemp -t "dbm.ini.XXXXXXXXX")
            config_file=$(echo "${config_file}" | sed 's|/dbm.ini.XXXXXXXXX.|/dbm.ini.|g') # macOS/mktemp fix
            config=$(input)
            echo "${config}" > "${config_file}"
        }

        cleanup_local() {
            { [ -f "${config_file}" ] && rm -rf "config_file"; } || true
        }

        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            '' "${config_file}" success
        End

        It 'correctly returns dependencies'
            When call init_config "$1" "$2"
            The status should be "$3"
            The variable config_docker_registry should equal 'DOCKER_REGISTRY'
            The variable config_docker_working_dir should equal 'DOCKER_WORKING_DIR'
            The variable config_docker_base_yml should equal 'DOCKER_BASE_YML'
            The variable config_docker_prod_yml should equal 'DOCKER_PROD_YML'
            The variable config_docker_dev_yml should equal 'DOCKER_DEV_YML'
            The variable config_docker_service should equal 'DOCKER_SERVICE_NAME'
            The variable config_docker_platforms should equal 'DOCKER_TARGET_PLATFORM'
        End
    End

    Describe 'init_config_value()'
        input() { %text
            #|DOCKER_BASE_YML='docker-compose.yml'
            #|UNQUOTED=unquoted
            #|DOUBLE_QUOTED="double quoted"
        }

        setup_local() {
            config_file=$(mktemp -t "dbm.ini.XXXXXXXXX")
            config_file=$(echo "${config_file}" | sed 's|/dbm.ini.XXXXXXXXX.|/dbm.ini.|g') # macOS/mktemp fix
            config=$(input)
            echo "${config}" > "${config_file}"
        }

        cleanup_local() {
            { [ -f "${config_file}" ] && rm -rf "config_file"; } || true
        }

        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            'DOCKER_BASE_YML' 'dummy.yml' 'docker-compose.yml' '' success
            'docker_base_yml' 'dummy.yml' 'docker-compose.yml' '' success
            'unknown'         'dummy.yml' 'dummy.yml'          '' success
            'unknown'         ''          ''                   '' success
            'UNQUOTED'        ''          'unquoted'           '' success
            'DOUBLE_QUOTED'   ''          'double quoted'      '' success
        End

        It 'correctly inits config values'
            When call init_config_value "$1" "$2"
            The status should be "$5"
            The output should eq "$3"
            The error should eq "$4"
        End
    End

    Describe 'is_valid_dependency()'
        input() { %text
            #|DBM_ALPINE_VERSION='original input'
        }

        setup_local() {
            config_file=$(mktemp -t "dbm.ini.XXXXXXXXX")
            config_file=$(echo "${config_file}" | sed 's|/dbm.ini.XXXXXXXXX.|/dbm.ini.|g') # macOS/mktemp fix
            config=$(input)
            echo "${config}" > "${config_file}"
        }

        cleanup_local() {
            { [ -f "${config_file}" ] && rm -rf "config_file"; } || true
        }

        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            'ALPINE hub.docker.com _ alpine 3.13.2-rc' '*' success
            '1:ALPINE hub.docker.com _ alpine 3.13.2-rc' '*' success
            '' '*' failure
            'ALPINE 3.13.2' 'Dependency has no repository link, skipping item*' failure
            'ALPINE hub.docker.com _ alpine 3.13.2-rc invalid' 'Dependency is malformed, skipping item*' failure
            '1:ALPINE XXX XXX XXX' "Line 1 of * is malformed, skipping item: DBM_ALPINE_VERSION='original input'" failure
            '1:ALPINE XXX' "Line 1 of * has no repository link, skipping item: DBM_ALPINE_VERSION='original input'" failure
        End

        It 'correctly validates dependencies'
            When call is_valid_dependency "$1"
            The status should be "$3"
            The output should match pattern "$2"
        End
    End
    
    Describe 'read_dependencies()'
        input() { %text
            #|DOCKER_WORKING_DIR='./'
            #|DOCKER_BASE_YML='docker-compose.yml'
            #|DOCKER_PROD_YML='docker-compose.prod.yml'
            #|DOCKER_DEV_YML='docker-compose.dev.yml'
            #|DOCKER_SERVICE_NAME='trust'
            #|DBM_BUILD_UID=1001
            #|DBM_BUILD_GID=1001
            #|DBM_ALPINE_VERSION=hub.docker.com/_/alpine 3.13.4
            #|DBM_GOLANG_VERSION=hub.docker.com/_/golang 1.16.3
            #|DBM_RESTIC_VERSION=github.com/restic/restic 0.12.0
        }

        expected() { %text
            #|8:ALPINE hub.docker.com _ alpine 3.13.4;9:GOLANG hub.docker.com _ golang 1.16.3;10:RESTIC github.com restic restic 0.12.0;
        }

        setup_local() {
            config_file=$(mktemp -t "dbm.ini.XXXXXXXXX")
            config_file=$(echo "${config_file}" | sed 's|/dbm.ini.XXXXXXXXX.|/dbm.ini.|g') # macOS/mktemp fix
            config=$(input)
            echo "${config}" > "${config_file}"
        }

        cleanup_local() {
            { [ -f "${config_file}" ] && rm -rf "config_file"; } || true
        }

        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            "${config_file}" success
        End

        It 'correctly returns dependencies'
            When call read_dependencies "$1" "$2"
            The status should be "$2"
            The output should eq "$(expected)"
        End
    End

    Describe 'read_stored_digest()'
        input() { %text
            #|github.com/restic/restic v0.12.0 sha:27f241334e9245a212bc2aba4956a5c0392e5940
            #|hub.docker.com/_/alpine v3.13.4 sha256:ec14c7992a97fc11425907e908340c6c3d6ff602f5f13d899e6b7027c9b4133a
            #|hub.docker.com/_/golang v1.16.3 sha256:13457efbeae175217436dbbdb9ba621bd42934a1cddcce2b8b60b99db4e11d12
            #|
        }

        setup_local() {
            config_digest_file=$(mktemp -t "dbm.digest.XXXXXXXXX")
            config_digest_file=$(echo "${config_digest_file}" | sed 's|/dbm.digest.XXXXXXXXX.|/dbm.digest.|g') # macOS/mktemp fix
            digests=$(input)
            echo "${digests}" > "${config_digest_file}"
        }

        cleanup_local() {
            { [ -f "${config_digest_file}" ] && rm -rf "config_digest_file"; } || true
        }

        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            'github.com/restic/restic' 'v0.12.0' 'sha:27f241334e9245a212bc2aba4956a5c0392e5940' success
            'hub.docker.com/_/alpine'  'v3.13.4' 'sha256:ec14c7992a97fc11425907e908340c6c3d6ff602f5f13d899e6b7027c9b4133a' success
            'hub.docker.com/_/golang'  'v1.16.3' 'sha256:13457efbeae175217436dbbdb9ba621bd42934a1cddcce2b8b60b99db4e11d12' success
            'invalid' 'invalid' '' failure
        End

        It 'correctly reads a stored digest'
            When call read_stored_digest "$1" "$2"
            The status should be "$4"
            The output should equal "$3"
        End
    End

    Describe 'read_update_stored_digest()'
        input() { %text
            #|github.com/restic/restic v0.12.0 sha:27f241334e9245a212bc2aba4956a5c0392e5940
            #|hub.docker.com/_/alpine v3.13.4 sha256:ec14c7992a97fc11425907e908340c6c3d6ff602f5f13d899e6b7027c9b4133a
            #|
        }

        expected() { %text
            #|github.com/restic/restic v0.12.0 sha:27f241334e9245a212bc2aba4956a5c0392e5940
            #|hub.docker.com/_/alpine v3.13.4 sha256:ec14c7992a97fc11425907e908340c6c3d6ff602f5f13d899e6b7027c9b4133a
            #|hub.docker.com/_/golang v1.16.3 sha256:13457efbeae175217436dbbdb9ba621bd42934a1cddcce2b8b60b99db4e11d12
            #|
        }

        setup_local() {
            config_digest_file=$(mktemp -t "dbm.digest.XXXXXXXXX")
            config_digest_file=$(echo "${config_digest_file}" | sed 's|/dbm.digest.XXXXXXXXX.|/dbm.digest.|g') # macOS/mktemp fix
            digests=$(input)
            echo "${digests}" > "${config_digest_file}"
        }

        cleanup_local() {
            { [ -f "${config_digest_file}" ] && rm -rf "config_digest_file"; } || true
        }

        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            'hub.docker.com/_/golang'  'v1.16.3' 'sha256:13457efbeae175217436dbbdb9ba621bd42934a1cddcce2b8b60b99db4e11d12' success
            'github.com/restic/restic' 'v0.12.0' 'sha:27f241334e9245a212bc2aba4956a5c0392e5940' success
        End

        It 'correctly reads and updates a stored digest'
            When call read_update_stored_digest "$1" "$2" "$3"
            The status should be "$4"
            The output should equal "$3"
            The contents of file "${config_digest_file}" should equal "$(expected)"
        End
    End
End