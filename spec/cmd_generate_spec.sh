#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/generate.sh' cmd generate
    Include lib/log.sh
    Include cmd/root.sh
    Include cmd/generate.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'
    Todo 'execute_generate()'

    Describe 'parse_generate_args()'
        Describe 'target'
            Parameters
                generate dev output.yml success
                generate prod output.yml success
            End

            It 'parses supported targets'
                When call parse_generate_args "$1" "$2" "$3"
                The status should be "$4"
                The variable arg_target should equal "$2"
                The variable arg_compose_file should equal "$3"
            End
        End

        Describe 'target'
            Parameters
                generate unknown failure 'ERROR: Expected target'
            End

            It 'rejects unsupported targets'
                When call parse_generate_args "$1" "$2"
                The status should be "$3"
                The output should match pattern '?Usage*'
                The error should equal "$4"
                The variable arg_target should be blank
                The variable arg_compose_file should be blank
            End
        End

        Describe 'output'
            Parameters
                generate dev failure 'ERROR: Expected output file'
            End

            It 'rejects unsupported targets'
                When call parse_generate_args "$1" "$2"
                The status should be "$3"
                The output should match pattern '?Usage*'
                The error should equal "$4"
                The variable arg_target should equal "$2"
                The variable arg_compose_file should be blank
            End
        End

        Describe 'output'
            Parameters
                generate dev output1.yml output2.yml failure "ERROR: Argument not supported: output2.yml"
            End

            It 'rejects unsupported flags'
                When call parse_generate_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The output should match pattern '?Usage*'
                The error should equal "$6"
                The variable arg_target should equal "$2"
                The variable arg_compose_file should equal "$3"
            End
        End

        Describe 'tag'
            Parameters
                generate dev output.yml --tag custom success
            End

            It 'parses --tag flag'
                When call parse_generate_args "$1" "$2" "$3" "$4" "$5"
                The status should be "$6"
                The variable arg_target should equal "$2"
                The variable arg_tag should equal "$5"
                The variable arg_services should be blank
            End
        End

        Describe 'tag'
            Parameters
                generate dev output.yml --tag failure 'ERROR: Missing tag argument'
            End

            It 'rejects --tag flag without argument'
                When call parse_generate_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The output should match pattern '?Usage*'
                The error should equal "$6"
                The variable arg_target should equal "$2"
                The variable arg_tag should be blank
                The variable arg_services should be blank
            End
        End

        Describe 'help'
            Parameters
                generate -h failure '?Generate*'
                generate --help failure '?Generate*'
            End

            It 'displays help'
                When call parse_generate_args "$1" "$2"
                The status should be "$3"
                The output should match pattern "$4"
            End
        End
    End

    Describe 'usage_generate()'
        It 'displays usage for generate command'
            When call usage_generate
            The output should match pattern '?Generate*'
        End
    End
End