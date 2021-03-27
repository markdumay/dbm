#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/remove.sh' cmd remove
    Include lib/log.sh
    Include cmd/root.sh
    Include cmd/remove.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'
    Todo 'execute_remove()'

    Describe 'parse_remove_args()'
        Describe 'target'
            Parameters
                remove dev success
                remove prod success
            End

            It 'parses supported targets'
                When call parse_remove_args "$1" "$2"
                The status should be "$3"
                The variable arg_target should equal "$2"
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'target'
            Parameters
                remove unknown failure 'ERROR: Expected target'
            End

            It 'rejects unsupported targets'
                When call parse_remove_args "$1" "$2"
                The status should be "$3"
                The output should match pattern '?Usage*'
                The error should equal "$4"
                The variable arg_target should be blank
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'no-digest'
            Parameters
                remove dev --no-digest success
            End

            It 'parses --no-digest flag'
                When call parse_remove_args "$1" "$2" "$3"
                The status should be "$4"
                The variable arg_no_digest should equal 'true'
            End
        End

        Describe 'help'
            Parameters
                remove -h success '?Remove*'
                remove --help success '?Remove*'
            End

            It 'displays help'
                When run parse_remove_args "$1" "$2"
                The status should be "$3"
                The output should match pattern "$4"
                The variable arg_target should be blank
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End
    End

    Describe 'usage_remove()'
        It 'displays usage for remove command'
            When run usage_remove
            The output should match pattern "?Remove*"
        End
    End
End