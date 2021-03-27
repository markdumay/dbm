#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/check.sh' cmd check
    Include lib/log.sh
    Include cmd/root.sh
    Include cmd/check.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'

    Todo 'execute_check_upgrades()'

    Describe 'parse_check_args()'
        Describe 'check'
            Parameters
                check success
            End

            It 'parses without flags'
                When call parse_check_args "$1"
                The status should be "$2"
                The variable arg_no_digest should equal 'false'
            End
        End

        Describe 'check'
            Parameters
                check arg failure 
            End

            It 'fails with any flag'
                When call parse_check_args "$1" "$2"
                The status should be "$3"
                The output should match pattern '?Usage*'
                The error should equal "ERROR: Argument not supported: $2"
            End
        End

        Describe 'no-digest'
            Parameters
                check --no-digest success
            End

            It 'parses --no-digest flag'
                When call parse_check_args "$1" "$2"
                The status should be "$3"
                The variable arg_no_digest should equal 'true'
            End
        End

        Describe 'help'
            Parameters
                check -h success '?Check*'
                check --help success '?Check*'
            End

            It 'displays help'
                When run parse_check_args "$1" "$2"
                The status should be "$3"
                The output should match pattern "$4"
            End
        End
    End

    Describe 'usage_check()'
        It 'displays usage for check command'
            When run usage_check
            The output should match pattern '?Check*'
        End
    End
End