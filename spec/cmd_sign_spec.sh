#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/sign.sh' cmd sign
    Include lib/log.sh
    Include cmd/root.sh
    Include cmd/sign.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'
    Todo 'execute_sign()'

    Describe 'parse_sign_args()'
        Describe 'target'
            Parameters
                sign dev success
                sign prod success
            End

            It 'parses supported targets'
                When call parse_sign_args "$1" "$2"
                The status should be "$3"
                The variable arg_target should equal "$2"
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'target'
            Parameters
                sign unknown failure 'ERROR: Expected target'
            End

            It 'rejects unsupported targets'
                When call parse_sign_args "$1" "$2"
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
                sign dev --no-digest success
            End

            It 'parses --no-digest flag'
                When call parse_sign_args "$1" "$2" "$3"
                The status should be "$4"
                The variable arg_no_digest should equal 'true'
            End
        End

        Describe 'tag'
            Parameters
                sign dev --tag custom success
            End

            It 'parses --tag flag'
                When call parse_sign_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The variable arg_target should equal "$2"
                The variable arg_tag should equal "$4"
                The variable arg_services should be blank
            End
        End

        Describe 'tag'
            Parameters
                sign dev --tag failure 'ERROR: Missing tag argument'
            End

            It 'rejects --tag flag without argument'
                When call parse_sign_args "$1" "$2" "$3"
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
                sign dev SERVICE1 SERVICE2 success
            End

            It 'parses --tag flag'
                When call parse_sign_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The variable arg_target should equal "$2"
                The variable arg_tag should be blank
                The variable arg_services should equal "$3 $4"
            End
        End

        Describe 'help'
            Parameters
                sign -h success '?Sign*'
                sign --help success '?Sign*'
            End

            It 'displays help'
                When run parse_sign_args "$1" "$2"
                The status should be "$3"
                The output should match pattern "$4"
                The variable arg_target should be blank
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End
    End

    Describe 'usage_sign()'
        It 'displays usage for sign command'
            When run usage_sign
            The output should match pattern '?Sign*'
        End
    End
End