#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/down.sh'
    Include lib/log.sh
    Include cmd/root.sh
    Include cmd/down.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'
    Todo 'execute_down()'

    Describe 'parse_down_args()'
        Describe 'target'
            Parameters
                down dev success
                down prod success
            End

            It 'parses supported targets'
                When call parse_down_args "$1" "$2"
                The status should be "$3"
                The variable arg_target should equal "$2"
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'target'
            Parameters
                down unknown failure 'ERROR: Expected target'
            End

            It 'rejects unsupported targets'
                When call parse_down_args "$1" "$2"
                The status should be "$3"
                The output should match pattern '?Usage*'
                The error should equal "$4"
                The variable arg_target should be blank
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'tag'
            Parameters
                down dev --tag custom success
            End

            It 'parses --tag flag'
                When call parse_down_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The variable arg_target should equal "$2"
                The variable arg_tag should equal "$4"
                The variable arg_services should be blank
            End
        End

        Describe 'tag'
            Parameters
                down dev --tag failure 'ERROR: Missing tag argument'
            End

            It 'rejects --tag flag without argument'
                When call parse_down_args "$1" "$2" "$3"
                The status should be "$4"
                The output should match pattern '?Usage*'
                The error should equal "$5"
                The variable arg_target should equal "$2"
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'services'
            Parameters
                down dev SERVICE1 SERVICE2 success
            End

            It 'parses --tag flag'
                When call parse_down_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The variable arg_target should equal "$2"
                The variable arg_tag should be blank
                The variable arg_services should equal "$3 $4"
            End
        End

        Describe 'help'
            Parameters
                down -h failure '?Down*'
                down --help failure '?Down*'
            End

            It 'displays help'
                When call parse_down_args "$1" "$2"
                The status should be "$3"
                The output should match pattern "$4"
                The variable arg_target should be blank
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End
    End

    Describe 'usage_down()'
        It 'displays usage for down command'
            When call usage_down
            The output should match pattern "?Down*"
        End
    End
End