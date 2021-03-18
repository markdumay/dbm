#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#======================================================================================================================
# Asks the user to confirm the operation.
#======================================================================================================================
# Outputs:
#   Returns 0 if the user confirmed the operation, returns 1 otherwise.
#======================================================================================================================
confirm_operation() {
    while true; do
        printf "Are you sure you want to continue? [y/N] "
        read -r yn
        yn=$(echo "${yn}" | tr '[:upper:]' '[:lower:]')

        case "${yn}" in
            y | yes )     return 0;;
            n | no | "" ) return 1;;
            * )           echo "Please answer y(es) or n(o)";;
        esac
    done
}

#======================================================================================================================
# Escapes a string considering special characters.
#======================================================================================================================
# Arguments:
#   $1 - String.
# Outputs:
#   Escaped string.
#======================================================================================================================
escape_string() {
    echo "$1" | sed -E 's/[\]+(&)/\1/g; s/&/\\&/g'
}

#=======================================================================================================================
# Validates if a variable is a valid positive integer.
#=======================================================================================================================
# Arguments:
#   $1 - Variable to test.
# Outputs:
#   Returns 0 if valid and returns 1 if not valid.
#=======================================================================================================================
is_number() {
    [ -n "$1" ] && [ -z "${1##[0-9]*}" ] && return 0 || return 1
}

#======================================================================================================================
# Encodes a variable to a url-safe variable using jq. For example, the string 'encode this' is encoded to 
# 'encode%20this'.
#======================================================================================================================
# Arguments:
#   $1 - Variable to encode.
# Outputs:
#   Url-encoded variable.
#======================================================================================================================
url_encode() {
    printf '%s' "$1" | jq -sRr @uri
}

#=======================================================================================================================
# Validates if required commands are available on the host. For example, the following command tests the availability of
# some common commands.
# 
# validate_dependencies 'awk cut date grep sed tr uname wc'
#=======================================================================================================================
# Arguments:
#   $1 - List of dependencies, separated by spaces.
# Outputs:
#   Returns 0 if valid and returns 1 if invalid.
#=======================================================================================================================
validate_dependencies() {
    dependencies="$1"
    missing=''

    # Check if required commands are available
    for dependency in $dependencies; do
        command -v "${dependency}" >/dev/null 2>&1 || missing="${missing}${dependency}, "
    done

    # Return findings
    [ -z "${missing}" ] && return 0
    missing=$(echo "${missing}" | sed 's/, $//g') # remove trailing ', '
    count=$(echo "${missing}" | wc -w)
    if [ "${count}" -eq 1 ]; then
        echo "Required command not found: ${missing}"
        return 1
    else
        echo "Required commands not found: ${missing}"
        return 1
    fi
}