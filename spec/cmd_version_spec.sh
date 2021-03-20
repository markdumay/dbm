#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/version.sh'
    Include lib/log.sh
    Include cmd/root.sh
    Include cmd/version.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'

    Describe 'execute_show_version()'
        It 'displays semantic version'
            When call execute_show_version "0.1.0"
            The output should end with "version 0.1.0"
        End
    End

    Describe 'parse_version_args()'
        Describe 'version'
            Parameters
                version success
            End

            It 'parses without flags'
                When call parse_version_args "$1"
                The status should be "$2"
            End
        End

        Describe 'version'
            Parameters
                version arg failure 
            End

            It 'fails with any flag'
                When call parse_version_args "$1" "$2"
                The status should be "$3"
                The output should match pattern '?Usage*'
                The error should equal "ERROR: Argument not supported: $2"
            End
        End

        Describe 'help'
            Parameters
                version -h failure '?Version*'
                version --help failure '?Version*'
            End

            It 'displays help'
                When call parse_version_args "$1" "$2"
                The status should be "$3"
                The output should match pattern "$4"
            End
        End
    End

    Describe 'usage_version()'
        It 'displays usage for version command'
            When call usage_version
            The output should match pattern '?Version*'
        End
    End

    Todo 'init_script_version()'
End