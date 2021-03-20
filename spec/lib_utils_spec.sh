#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'lib/utils.sh'
    Include lib/utils.sh

    Todo 'confirm_operation()'
    Todo 'escape_string()'
    Todo 'is_number()'
    Todo 'url_encode()'
    Todo 'get_absolute_path()'

    Describe 'validate_dependencies()'
        Parameters
            'echo printf' '' success
        End

        It 'confirms available commands'
            When call validate_dependencies "$1"
            The status should be "$3"
            The output should equal "$2"
        End
    End

    Describe 'validate_dependencies()'
        random1() { value1=$(uuidgen); }
        Before 'random1'
        
        It 'confirms a missing command'
            When call validate_dependencies "${value1}"
            The status should be failure
            The output should start with 'Required command not found: '
        End
    End

    Describe 'validate_dependencies()'
        random1() { value1=$(uuidgen); }
        random2() { value2=$(uuidgen); }
        Before 'random1' 'random2'
        
        It 'confirms multiple missing commands'
            When call validate_dependencies "${value1} ${value2}"
            The status should be failure
            The output should start with 'Required commands not found: '
        End
    End
End