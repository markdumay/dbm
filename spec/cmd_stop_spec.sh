#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/stop.sh' cmd stop
    Include lib/log.sh
    Include cmd/root.sh
    Include cmd/stop.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'
    Todo 'execute_stop()'

    Describe 'parse_stop_args()'
        Describe 'target'
            Parameters
                stop dev success
                stop prod success
            End

            It 'parses supported targets'
                When call parse_stop_args "$1" "$2"
                The status should be "$3"
                The variable arg_target should equal "$2"
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'target'
            Parameters
                stop unknown failure 'ERROR: Expected target'
            End

            It 'rejects unsupported targets'
                When call parse_stop_args "$1" "$2"
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
                stop dev --tag custom success
            End

            It 'parses --tag flag'
                When call parse_stop_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The variable arg_target should equal "$2"
                The variable arg_tag should equal "$4"
                The variable arg_services should be blank
            End
        End

        Describe 'tag'
            Parameters
                stop dev --tag failure 'ERROR: Missing tag argument'
            End

            It 'rejects --tag flag without argument'
                When call parse_stop_args "$1" "$2" "$3"
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
                stop dev SERVICE1 SERVICE2 success
            End

            It 'parses --tag flag'
                When call parse_stop_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The variable arg_target should equal "$2"
                The variable arg_tag should be blank
                The variable arg_services should equal "$3 $4"
            End
        End

        Describe 'help'
            Parameters
                stop -h failure '?Stop*'
                stop --help failure '?Stop*'
            End

            It 'displays help'
                When call parse_stop_args "$1" "$2"
                The status should be "$3"
                The output should match pattern "$4"
                The variable arg_target should be blank
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End
    End

    Describe 'usage_stop()'
        It 'displays usage for stop command'
            When call usage_stop
            The output should match pattern '?Stop*'
        End
    End
End