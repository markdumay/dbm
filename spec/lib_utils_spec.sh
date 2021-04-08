#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'lib/utils.sh' utils
    Include lib/log.sh
    Include lib/utils.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'

    Describe 'confirm_operation()'
        Parameters
            'Are you sure you want to continue? [y/N] '
        End

        It 'handles confirmations'
            Data 
                #|Y
            End
            When call confirm_operation
            The status should be success
            The output should equal "$1"
        End

        It 'handles rejections'
            Data 
                #|N
            End
            When call confirm_operation
            The status should be failure
            The output should equal "$1"
        End

        It 'handles incorrect input'
            Data 
                #|X
            End
            When call confirm_operation
            The status should be failure
            The output should match pattern "*Please answer y(es) or n(o)*"
        End
    End

    Describe 'escape_string()'
        Parameters
            'xxx' 'xxx' success
            '&' '\&' success
        End

        It 'escapes input strings'
            When call escape_string "$1"
            The status should be "$3"
            The output should equal "$2"
        End
    End

    Describe 'get_absolute_path()'
        Parameters
            'temp' "${PWD}/temp" success
            '/temp' '/temp' success
            '//temp' '/temp' success
            './temp' "${PWD}/temp" success
            "/$(uuidgen)/$(uuidgen)/$(uuidgen)" '' failure
        End

        It 'escapes input strings'
            When call get_absolute_path "$1"
            The status should be "$3"
            The output should equal "$2"
        End
    End

    Describe 'is_number()'
        Parameters
            '1234567890' success
            'abc' failure
            '-1' failure
            '' failure
            '1,0a' failure
            '1.0' failure
            '9,0' failure
        End

        It 'correctly validates string input'
            When call is_number "$1"
            The status should be "$2"
        End
    End

    Describe 'url_encode()'
        Parameters
            'encode this' 'encode%20this' success
            '123&456' '123%26456' success
        End

        It 'correctly encodes url arguments'
            When call url_encode "$1"
            The status should be "$3"
            The output should eq "$2"
        End
    End

    Describe 'validate_dependencies()'
        Parameters
            'echo printf' '' success
        End

        It 'confirms available commands'
            When call validate_dependencies "$1"
            The status should be "$3"
            The output should equal "$2"
        End
        
        It 'confirms a missing command'
            When call validate_dependencies "$(uuidgen)"
            The status should be failure
            The error should start with 'ERROR: Required command not found: '
        End
        
        It 'confirms multiple missing commands'
            When call validate_dependencies "$(uuidgen) $(uuidgen)"
            The status should be failure
            The error should start with 'ERROR: Required commands not found: '
        End
    End
End