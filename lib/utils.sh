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
# Retrieves the absolute path for a given path. If the provided path is relative it is appended to the provided base
# directory. The path needs to exist, the filename does not need to exist.
#=======================================================================================================================
# Arguments:
#   $1 - Base directory.
#   $2 - Path, either relative or absolute.
# Outputs:
#   Absolute path, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
get_absolute_path() {
    basedir="$1"
    path="$2"
    result=''

    start=$(echo "${path}" | cut -c-1)
    [ "${start}" = '/' ] && result="${path}" || result="${basedir}/${path}"
    
    realpath "${result}" 2> /dev/null && return 0 || return 1
}

#=======================================================================================================================
# Validates if a variable is a valid, unsigned positive integer.
#=======================================================================================================================
# Arguments:
#   $1 - Variable to test.
# Outputs:
#   Returns 0 if valid and returns 1 if not valid.
#=======================================================================================================================
is_number() {
    case "$1" in
        ''|*[!0-9]* ) return 1 ;;
        * ) return 0
    esac
}

#======================================================================================================================
# Encodes a variable to a url-safe variable using jq. For example, the string 'encode this' is encoded to 
# 'encode%20this'. The encoding does not recognize valid urls, so only provide parts that need to be encoded. For
# example, 'http://example.com?arg=123&456' is encoded to 'http%3A%2F%2Fexample.com%3Farg%3D123%26456'. Instead, only
# encode the portion '123&456' and append the result '123%26456' to the base url 'http://example.com?arg='.
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
    IFS=' '
    for dependency in $dependencies; do
        command -v "${dependency}" >/dev/null 2>&1 || missing="${missing}${dependency}, "
    done

    # Return findings
    [ -z "${missing}" ] && return 0
    missing=$(echo "${missing}" | sed 's/, $//g') # remove trailing ', '
    count=$(echo "${missing}" | wc -w)
    if [ "${count}" -eq 1 ]; then
        err "Required command not found: ${missing}"
        return 1
    else
        err "Required commands not found: ${missing}"
        return 1
    fi
}