#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/config.sh'
    Include lib/log.sh
    Include cmd/root.sh
    Include cmd/config.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'
    Todo 'execute_config()'

    Describe 'parse_config_args()'
        Describe 'target'
            Parameters
                config dev output.yml success
                config prod output.yml success
            End

            It 'parses supported targets'
                When call parse_config_args "$1" "$2" "$3"
                The status should be "$4"
                The variable arg_target should equal "$2"
                The variable arg_config_file should equal "$3"
            End
        End

        Describe 'target'
            Parameters
                config unknown failure 'ERROR: Expected target'
            End

            It 'rejects unsupported targets'
                When call parse_config_args "$1" "$2"
                The status should be "$3"
                The output should match pattern '?Usage*'
                The error should equal "$4"
                The variable arg_target should be blank
                The variable arg_config_file should be blank
            End
        End

        Describe 'output'
            Parameters
                config dev failure 'ERROR: Expected output file'
            End

            It 'rejects unsupported targets'
                When call parse_config_args "$1" "$2"
                The status should be "$3"
                The output should match pattern '?Usage*'
                The error should equal "$4"
                The variable arg_target should equal "$2"
                The variable arg_config_file should be blank
            End
        End

        Describe 'output'
            Parameters
                config dev output1.yml output2.yml failure "ERROR: Argument not supported: output2.yml"
            End

            It 'rejects unsupported flags'
                When call parse_config_args "$1" "$2" "$3" "$4"
                The status should be "$5"
                The output should match pattern '?Usage*'
                The error should equal "$6"
                The variable arg_target should equal "$2"
                The variable arg_config_file should equal "$3"
            End
        End

        Describe 'help'
            Parameters
                config -h failure '?Config*'
                config --help failure '?Config*'
            End

            It 'displays help'
                When call parse_config_args "$1" "$2"
                The status should be "$3"
                The output should match pattern "$4"
            End
        End
    End

    Describe 'usage_config()'
        It 'displays usage for config command'
            When call usage_config
            The output should match pattern '?Config*'
        End
    End
End