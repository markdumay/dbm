#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly RW_DIRS='/tmp'


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Validates if the current shell user has R/W access to selected directories. The script terminates if a directory is
# not found, or if the permissions are incorrect.
#=======================================================================================================================
# Outputs:
#   Non-zero exit code in case of errors.
#=======================================================================================================================
validate_access() {
    # skip when R/W dirs are not specified
    if [ -n "${RW_DIRS}" ]; then
        # print directories that do not have R/W access
        dirs=$(eval "find ${RW_DIRS} -xdev -type d \
            -exec sh -c '(test -r \"\$1\" && test -w \"\$1\") || echo \"\$1\"' _ {} \; 2> /dev/null")
        result="$?"

        # capture result:
        # - non-zero result implies a directory cannot be found
        # - non-zero dirs captures directories that do not have R/W access
        [ "${result}" -ne 0 ] && echo "ERROR: Missing one or more directories: ${RW_DIRS}" && exit 1
        [ -n "${dirs}" ] && echo "ERROR: Incorrect permissions: ${dirs}" && exit 1
    fi
}

#=======================================================================================================================
# Main entrypoint for the script.
#=======================================================================================================================
main() {
    # Validate r/w access to key directories
    validate_access

    # Display a test message and run as daemon (waiting forever)
    cat /message.txt
    trap : TERM INT
    (while true; do sleep infinity; done) & wait
}

main "$@"