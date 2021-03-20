#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/build.sh'
    Include lib/log.sh
    Include cmd/root.sh
    Include cmd/build.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'

    Describe 'display_time()'
        Parameters
            11617 '3 hours 13 minutes and 37 seconds'
            42 '42 seconds'
            662 '11 minutes and 2 seconds'
        End

        It 'displays time'
            When call display_time "$1"
            The output should equal "$2"
        End
    End

    Todo 'execute_build()'

    Describe 'parse_build_args()'
        Describe 'target'
            Parameters
                build dev success
                build prod success
            End

            It 'parses supported targets'
                When call parse_build_args "$1" "$2"
                The status should be "$3"
                The variable arg_target should equal "$2"
                The variable arg_no_cache should equal 'false'
                The variable arg_platforms should be blank
                The variable arg_push should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'target'
            Parameters
                build unknown failure 'ERROR: Expected target'
            End

            It 'rejects unsupported targets'
                When call parse_build_args "$1" "$2"
                The status should be "$3"
                The output should match pattern '?Usage*'
                The error should equal "$4"
                The variable arg_target should be blank
                The variable arg_no_cache should equal 'false'
                The variable arg_platforms should be blank
                The variable arg_push should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'no-cache'
            Parameters
                build dev --no-cache success
            End

            It 'parses --no-cache flag'
                When call parse_build_args "$1" "$2" "$3"
                The status should be "$4"
                The variable arg_target should equal "$2"
                The variable arg_no_cache should equal 'true'
                The variable arg_platforms should be blank
                The variable arg_push should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'platforms'
            Parameters
                build dev --push --platforms linux/amd64,linux/arm64 success
            End

            It 'parses --platforms flag'
                When call parse_build_args "$1" "$2" "$3" "$4" "$5"
                The status should be "$6"
                The variable arg_target should equal "$2"
                The variable arg_no_cache should equal 'false'
                The variable arg_platforms should equal "$5"
                The variable arg_push should equal 'true'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'platforms'
            Parameters
                build dev --push --platforms failure 'ERROR: Missing platform argument'
            End

            It 'rejects --platforms flag without argument'
                When call parse_build_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The output should match pattern '?Usage*'
                The error should equal "$6"
                The variable arg_target should equal "$2"
                The variable arg_no_cache should equal 'false'
                The variable arg_platforms should be blank
                The variable arg_push should equal 'true'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'platforms'
            Parameters
                build dev --platforms linux/amd64,linux/arm64 failure "ERROR: Add '--push' for multi-architecture build"
            End

            It 'rejects --platforms flag without --push flag'
                When call parse_build_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The output should match pattern '?Usage*'
                The error should equal "$6"
                The variable arg_target should equal "$2"
                The variable arg_no_cache should equal 'false'
                The variable arg_platforms should equal "$4"
                The variable arg_push should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'push'
            Parameters
                build dev --push success
            End

            It 'parses --push flag'
                When call parse_build_args "$1" "$2" "$3"
                The status should be "$4"
                The variable arg_target should equal "$2"
                The variable arg_no_cache should equal 'false'
                The variable arg_platforms should be blank
                The variable arg_push should equal 'true'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'tag'
            Parameters
                build dev --tag custom success
            End

            It 'parses --tag flag'
                When call parse_build_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The variable arg_target should equal "$2"
                The variable arg_no_cache should equal 'false'
                The variable arg_platforms should be blank
                The variable arg_push should equal 'false'
                The variable arg_tag should equal "$4"
                The variable arg_services should be blank
            End
        End

        Describe 'tag'
            Parameters
                build dev --tag failure 'ERROR: Missing tag argument'
            End

            It 'rejects --tag flag without argument'
                When call parse_build_args "$1" "$2" "$3"
                The status should be "$4"
                The output should match pattern '?Usage*'
                The error should equal "$5"
                The variable arg_target should equal "$2"
                The variable arg_no_cache should equal 'false'
                The variable arg_platforms should be blank
                The variable arg_push should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'services'
            Parameters
                build dev SERVICE1 SERVICE2 success
            End

            It 'parses --tag flag'
                When call parse_build_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The variable arg_target should equal "$2"
                The variable arg_no_cache should equal 'false'
                The variable arg_platforms should be blank
                The variable arg_push should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should equal "$3 $4"
            End
        End

        Describe 'help'
            Parameters
                build -h failure '?Build*'
                build --help failure '?Build*'
            End

            It 'displays help'
                When call parse_build_args "$1" "$2"
                The status should be "$3"
                The output should match pattern "$4"
                The variable arg_target should be blank
                The variable arg_no_cache should equal 'false'
                The variable arg_platforms should be blank
                The variable arg_push should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End
    End

    Describe 'usage_build()'
        It 'displays usage for build command'
            When call usage_build
            The output should match pattern '?Build*'
        End
    End
End