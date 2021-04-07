#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/info.sh' cmd info
    Include lib/log.sh
    Include cmd/root.sh
    Include cmd/info.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'

    Describe 'execute_show_info()'
        Parameters
            '0.1' os arch success
        End

        It 'executes the info command correctly'
            When call execute_show_info "$1" "$2" "$3"
            The output should end with "$2/$3" 
            The status should be "$4"
        End
    End

    Describe 'parse_info_args()'
        Describe 'info'
            Parameters
                info success
            End

            It 'parses without flags'
                When call parse_info_args "$1"
                The status should be "$2"
            End
        End

        Describe 'info'
            Parameters
                info arg failure 
            End

            It 'fails with any flag'
                When call parse_info_args "$1" "$2"
                The status should be "$3"
                The output should match pattern '?Usage*'
                The error should equal "ERROR: Argument not supported: $2"
            End
        End

        Describe 'help'
            Parameters
                info -h success '?Info*'
                info --help success '?Info*'
            End

            It 'displays help'
                When run parse_info_args "$1" "$2"
                The status should be "$3"
                The output should match pattern "$4"
            End
        End
    End

    Describe 'usage_info()'
        It 'displays usage for info command'
            When run usage_info
            The output should match pattern '?Info*'
        End
    End
End