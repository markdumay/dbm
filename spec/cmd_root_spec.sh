#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/root.sh' cmd root
    Include lib/log.sh
    Include cmd/root.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'

    Describe 'parse_arg()'
        Parameters
            'valid' 'valid' success
            '-invalid' '' failure
        End

        It 'parses an argument correctly'
            When call parse_arg "$1"
            The output should equal "$2"
            The status should be "$3"
        End
    End

    Describe 'parse_args()'
        parse_build_args() { printf '%s' 'parse_build_args '; echo "$@"; return 0; }
        parse_check_args() { printf '%s' 'parse_check_args '; echo "$@"; return 0; }
        parse_deploy_args() { printf '%s' 'parse_deploy_args '; echo "$@"; return 0; }
        parse_down_args() { printf '%s' 'parse_down_args '; echo "$@"; return 0; }
        parse_generate_args() { printf '%s' 'parse_generate_args '; echo "$@"; return 0; }
        parse_info_args() { printf '%s' 'parse_info_args '; echo "$@"; return 0; }
        parse_remove_args() { printf '%s' 'parse_remove_args '; echo "$@"; return 0; }
        parse_sign_args() { printf '%s' 'parse_sign_args '; echo "$@"; return 0; }
        parse_stop_args() { printf '%s' 'parse_stop_args '; echo "$@"; return 0; }
        parse_trust_args() { printf '%s' 'parse_trust_args '; echo "$@"; return 0; }
        parse_up_args() { printf '%s' 'parse_up_args '; echo "$@"; return 0; }
        parse_version_args() { printf '%s' 'parse_version_args '; echo "$@"; return 0; }

        Parameters
            build '*parse_build_args build*' success
            check '*parse_check_args check*' success
            deploy '*parse_deploy_args deploy*' success
            down '*parse_down_args down*' success
            generate '*parse_generate_args generate*' success
            info '*parse_info_args info*' success
            remove '*parse_remove_args remove*' success
            sign '*parse_sign_args sign*' success
            stop '*parse_stop_args stop*' success
            trust '*parse_trust_args trust*' success
            up '*parse_up_args up*' success
            version '*parse_version_args version*' success
        End

        It 'parses commands correctly'
            When call parse_args "$1" "$2"
            The output should match pattern "$2"
            The status should be "$3"
        End
    End

    Describe 'parse_args()'
        Parameters
            '-h' '?Docker Build Manager*' '*' success
            '--help' '?Docker Build Manager*' '*' success
            unknown '?Usage*' '*FATAL: Command not supported: unknown*' failure
        End

        It 'parses commands correctly'
            When run parse_args "$1" "$2"
            The output should match pattern "$2"
            The error should match pattern "$3"
            The status should be "$4"
        End
    End

    Describe 'usage()'
        It 'displays usage for DBM'
            When run usage
            The output should match pattern '?Docker Build Manager*'
        End
    End
End