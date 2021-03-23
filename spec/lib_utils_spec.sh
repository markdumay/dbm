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

    Todo 'confirm_operation()'
    Todo 'escape_string()'
    Todo 'is_number()'
    Todo 'url_encode()'
    Todo 'get_absolute_path()'

    Describe 'validate_dependencies()'
        random1() { value1=$(uuidgen); }
        random2() { value2=$(uuidgen); }
        BeforeAll 'random1' 'random2'

        Parameters
            'echo printf' '' success
        End

        It 'confirms available commands'
            When call validate_dependencies "$1"
            The status should be "$3"
            The output should equal "$2"
        End
        
        It 'confirms a missing command'
            When call validate_dependencies "${value1}"
            The status should be failure
            The error should start with 'ERROR: Required command not found: '
        End
        
        It 'confirms multiple missing commands'
            When call validate_dependencies "${value1} ${value2}"
            The status should be failure
            The error should start with 'ERROR: Required commands not found: '
        End
    End
End