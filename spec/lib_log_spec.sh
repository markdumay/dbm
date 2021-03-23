#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'lib/log.sh' log
    Include lib/log.sh

    Describe '_msg()'
        Parameters
            'default' '' '[TEST] ' 'DEBUG' 'Debug message' '[TEST] DEBUG: Debug message' success
            'default' '' '[TEST] ' 'INFO'  'Info message'  '[TEST] Info message'         success
            'default' '' '[TEST] ' 'WARN'  'Warn message'  '[TEST] WARN:  Warn message'  success
            'default' '' '[TEST] ' 'ERROR' 'Error message' '[TEST] ERROR: Error message' success
            'default' '' '[TEST] ' 'FATAL' 'Fatal message' '[TEST] FATAL: Fatal message' success

            'pretty' '2021-03-14T16:55:45Z' '' 'DEBUG' 'Debug message' '2021-03-14T16:55:45Z | DEBUG | Debug message' success
            'pretty' '2021-03-14T16:55:45Z' '' 'INFO'  'Info message'  '2021-03-14T16:55:45Z | INFO  | Info message'  success
            'pretty' '2021-03-14T16:55:45Z' '' 'WARN'  'Warn message'  '2021-03-14T16:55:45Z | WARN  | Warn message'  success
            'pretty' '2021-03-14T16:55:45Z' '' 'ERROR' 'Error message' '2021-03-14T16:55:45Z | ERROR | Error message' success
            'pretty' '2021-03-14T16:55:45Z' '' 'FATAL' 'Fatal message' '2021-03-14T16:55:45Z | FATAL | Fatal message' success
        
            'json' '2021-03-14T16:55:45Z' '' 'DEBUG' 'Debug message' '{"time":"2021-03-14T16:55:45Z","level":"debug","message":"Debug message"}' success
            'json' '2021-03-14T16:55:45Z' '' 'INFO'  'Info message'  '{"time":"2021-03-14T16:55:45Z","level":"info","message":"Info message"}'   success
            'json' '2021-03-14T16:55:45Z' '' 'WARN'  'Warn message'  '{"time":"2021-03-14T16:55:45Z","level":"warn","message":"Warn message"}'   success
            'json' '2021-03-14T16:55:45Z' '' 'ERROR' 'Error message' '{"time":"2021-03-14T16:55:45Z","level":"error","message":"Error message"}' success
            'json' '2021-03-14T16:55:45Z' '' 'FATAL' 'Fatal message' '{"time":"2021-03-14T16:55:45Z","level":"fatal","message":"Fatal message"}' success
        End

        It 'formats a log message'
            When call _msg "$1" "$2" "$3" "$4" "$5"
            The status should be "$7"
            The output should equal "$6"
        End
    End

    Describe 'debug()'
        setup() { set_log_format "default"; set_log_color 'false'; }
        Before 'setup'

        Parameters
            'Debug message' 'DEBUG: Debug message' success
        End

        It 'displays a debug message with default formatting'
            When call debug "$1"
            The status should be "$3"
            The output should equal "$2"
        End
    End

    Describe 'log()'
        date() {
            echo '2021-03-14T16:55:45Z'
        }

        setup() { set_log_format "pretty"; set_log_color 'false'; }
        Before 'setup'

        Parameters
            'Info message' '2021-03-14T16:55:45Z | INFO  | Info message' success
        End

        It 'displays a log message with pretty formatting'
            When call log "$1"
            The status should be "$3"
            The output should equal "$2"
        End
    End

    Describe 'warn()'
        date() {
            echo '2021-03-14T16:55:45Z'
        }

        setup() { set_log_format "json"; set_log_color 'false'; }
        Before 'setup'

        Parameters
            'Warn message' '{"time":"2021-03-14T16:55:45Z","level":"warn","message":"Warn message"}' success
        End

        It 'displays a warning with json formatting'
            When call warn "$1"
            The status should be "$3"
            The error should equal "$2"
        End
    End

    Describe 'err()'
        setup() { set_log_format "default"; set_log_color 'false'; }
        Before 'setup'

        Parameters
            'Error message' 'ERROR: Error message' success
        End

        It 'displays an error message with default formatting'
            When call err "$1"
            The status should be "$3"
            The error should equal "$2"
        End
    End

    Describe 'log()'
        date() {
            echo '2021-03-14T16:55:45Z'
        }

        # shellcheck disable=SC2034
        setup() { temp_file=$(mktemp -t "log_spec.XXXXXXXXX"); log_file="${temp_file}"; set_log_color 'false'; \
                  log_file_timestamp='2021-03-14T16:55:45Z'; }
        clean() { rm -rf "${temp_file}"; } 
        Before 'setup'
        After 'clean'

        Parameters
            'Log message' "2021-03-14T16:55:45Z Log message" success
        End

        It 'appends a log file with default formatting'
            When call log "$1"
            The status should be "$3"
            The output should equal "$1"
            The contents of file "${log_file}" should equal "$2"
        End
    End

End