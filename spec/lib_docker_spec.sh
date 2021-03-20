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


#   --no-cache                  Do not use cache when building the image
#   --platforms <platforms...>  Targeted multi-architecture platforms
#                               (comma separated)
#   --push                      Push image to Docker Registry
#   --tag <tag>                 Image tag override


    # compose_file="$1"
    # services="$2"
    # no_cache="$3"


    Describe 'build_image()' test
        Describe 'regular'
            Parameters
                "${app_compose_file}" ''         'false' 'alpine-test uses an image, skipping?Building dbm-test*' success
                "${app_compose_file}" ''         'true'  'alpine-test uses an image, skipping?Building dbm-test*' success
                "${app_compose_file}" 'dbm-test' 'false' 'Building dbm-test*' success
            End

            It 'builds a development image'
                When call build_image "$1" "$2" "$3"
                The status should be "$5"
                The output should start with 'Successfully built'
                The error should match pattern "$4"
            End
        End
    End



    Todo 'deploy_stack()'
    Todo 'get_arch()'
    Todo 'get_os()'
    Todo 'push_image()'
    Todo 'stop_container()'
    Todo 'validate_platforms()'
End