#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/up.sh' cmd up
    Include lib/log.sh
    Include cmd/root.sh
    Include cmd/up.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'

    Describe 'execute_up()'
        bring_container_up() { printf '%s' 'bring_container_up '; echo "$@"; return 0; }

        Parameters
            compose-file services true true sh 'bring_container_up compose-file services true true sh' success
        End

        It 'executes the up command correctly'
            When call execute_up "$1" "$2" "$3" "$4" "$5"
            The output should end with "$6"
            The status should be "$7"
        End
    End

    Describe 'parse_up_args()'
        Describe 'target'
            Parameters
                up dev success
                up prod success
            End

            It 'parses supported targets'
                When call parse_up_args "$1" "$2"
                The status should be "$3"
                The variable arg_target should equal "$2"
                The variable arg_detached should equal 'false'
                The variable arg_shell should equal 'sh'
                The variable arg_terminal should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'target'
            Parameters
                up unknown failure 'ERROR: Expected target'
            End

            It 'rejects unsupported targets'
                When call parse_up_args "$1" "$2"
                The status should be "$3"
                The output should match pattern '?Usage*'
                The error should equal "$4"
                The variable arg_target should be blank
                The variable arg_detached should equal 'false'
                The variable arg_shell should equal 'sh'
                The variable arg_terminal should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'detached'
            Parameters
                up dev -d success
                up dev --detached success
            End

            It 'parses --detached flag'
                When call parse_up_args "$1" "$2" "$3"
                The status should be "$4"
                The variable arg_target should equal "$2"
                The variable arg_detached should equal 'true'
                The variable arg_shell should equal 'sh'
                The variable arg_terminal should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'shell' test
            Parameters
                up dev --shell custom success
            End

            It 'parses --shell flag'
                When call parse_up_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The variable arg_target should equal "$2"
                The variable arg_detached should equal 'false'
                The variable arg_shell should equal 'custom'
                The variable arg_terminal should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'shell' test
            Parameters
                up dev --shell failure 'ERROR: Missing shell argument'
            End

            It 'rejects --shell flag without argument'
                When call parse_up_args "$1" "$2" "$3"
                The status should be "$4"
                The output should match pattern '?Usage*'
                The error should equal "$5"
                The variable arg_target should equal "$2"
                The variable arg_detached should equal 'false'
                The variable arg_shell should equal 'sh'
                The variable arg_terminal should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'terminal'
            Parameters
                up dev -t success
                up dev --terminal success
            End

            It 'parses --terminal flag'
                When call parse_up_args "$1" "$2" "$3"
                The status should be "$4"
                The variable arg_target should equal "$2"
                The variable arg_detached should equal 'false'
                The variable arg_shell should equal 'sh'
                The variable arg_terminal should equal 'true'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'terminal'
            Parameters
                up dev -t -d failure 'ERROR: Specify either detached mode or terminal mode'
                up dev --terminal --detached failure 'ERROR: Specify either detached mode or terminal mode'
            End

            It 'rejects --terminal --detached flags'
                When call parse_up_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The output should match pattern '?Usage*'
                The error should equal "$6"
                The variable arg_target should equal "$2"
                The variable arg_detached should equal 'false'
                The variable arg_shell should equal 'sh'
                The variable arg_terminal should equal 'true'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'no-digest'
            Parameters
                up dev --no-digest success
            End

            It 'parses --no-digest flag'
                When call parse_up_args "$1" "$2" "$3"
                The status should be "$4"
                The variable arg_no_digest should equal 'true'
            End
        End

        Describe 'tag'
            Parameters
                up dev --tag custom success
            End

            It 'parses --tag flag'
                When call parse_up_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The variable arg_target should equal "$2"
                The variable arg_detached should equal 'false'
                The variable arg_shell should equal 'sh'
                The variable arg_terminal should equal 'false'
                The variable arg_tag should equal "$4"
                The variable arg_services should be blank
            End
        End

        Describe 'tag'
            Parameters
                up dev --tag failure 'ERROR: Missing tag argument'
            End

            It 'rejects --tag flag without argument'
                When call parse_up_args "$1" "$2" "$3"
                The status should be "$4"
                The output should match pattern '?Usage*'
                The error should equal "$5"
                The variable arg_target should equal "$2"
                The variable arg_detached should equal 'false'
                The variable arg_shell should equal 'sh'
                The variable arg_terminal should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'services'
            Parameters
                up dev SERVICE1 SERVICE2 success
            End

            It 'parses services arguments'
                When call parse_up_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The variable arg_target should equal "$2"
                The variable arg_detached should equal 'false'
                The variable arg_shell should equal 'sh'
                The variable arg_terminal should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should equal "$3 $4"
            End
        End

        Describe 'services'
            Parameters
                up dev -t SERVICE1 SERVICE2 failure 'ERROR: Terminal mode supports one service only'
            End

            It 'rejects multiple services in terminal mode'
                When call parse_up_args "$1" "$2" "$3" "$4" "$5"
                The status should be "$6"
                The output should match pattern '?Usage*'
                The error should equal "$7"
                The variable arg_target should equal "$2"
                The variable arg_detached should equal 'false'
                The variable arg_shell should equal 'sh'
                The variable arg_terminal should equal 'true'
                The variable arg_tag should be blank
                The variable arg_services should equal "$4 $5"
            End
        End

        Describe 'help'
            Parameters
                up -h success '?Up*'
                up --help success '?Up*'
            End

            It 'displays help'
                When run parse_up_args "$1" "$2"
                The status should be "$3"
                The output should match pattern "$4"
                The variable arg_target should be blank
                The variable arg_detached should equal 'false'
                The variable arg_shell should equal 'sh'
                The variable arg_terminal should equal 'false'
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End
    End

    Describe 'usage_up()'
        It 'displays usage for up command'
            When run usage_up
            The output should match pattern '?Up*'
        End
    End
End