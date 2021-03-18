#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly DBM_CONFIG_FILE='dbm.ini'


#=======================================================================================================================
# Variables
#=======================================================================================================================
config_docker_working_dir=''
config_docker_base_yml=''
config_docker_prod_yml=''
config_docker_dev_yml=''
# TODO: rename service to stack
config_docker_service=''
config_docker_platforms=''
config_file=''

#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Reads all key/value pairs beginning with 'DBM_*' from the default config file. The output is written to stdout with
# the prefix 'export ' for each line.
#=======================================================================================================================
# Outputs:
#   Writes matching key/value pairs to stdout.
#=======================================================================================================================
# shellcheck disable=SC2059
export_env_values() {
    [ ! -f "${config_file}" ] && echo "Cannot find config file: ${config_file}" && return 1
    
    # retrieve all custom variables from the DBM config file
    # remove all comments and trailing spaces; separate each dependency by a ';'
    vars=$(grep '^DBM_.*=.*' "${config_file}" | sed 's/^DBM_//g')
    vars=$(printf "${vars}\n\n" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/;/g')
    vars=$(printf "${vars}" | sed -e 's/\s*#.*$//;s/[[:space:]]*$//;')
    results=''

    # remove the second argument if the line contains three arguments (such as the url for a dependency)
    IFS=';' # initialize vars separator
    for item in $vars; do
        count=$(echo "${item}" | wc -w) # identify number of parsed arguments (should be 2 or 3)
        if [ "${count}" -eq 1 ]; then
            results="${results}export ${item}\n"
        elif [ "${count}" -eq 2 ]; then
            entry=$(echo "${item}" | sed 's/=/ /g' | awk  '{print $1, $3}' | sed 's/ /=/g')
            results="${results}export ${entry}\n"
        else
            echo "Invalid entry in '${config_file}': ${item}"
            return 1
        fi
    done

    printf "${results}"
    return 0
}

#=======================================================================================================================
# Reads a setting from the configuration file.
#=======================================================================================================================
# Arguments:
#   $1 - Name of the setting (case insensitive) to read.
#   $2 - Default value if setting not found.
# Outputs:
#   Writes setting to stdout.
#=======================================================================================================================
init_config_value() {
    match=$(grep -in "^$1=" "${config_file}" 2> /dev/null) # read entry from config file
    line=$(echo "${match}" | awk -F':' '{print $1}') # read line number
    value=$(echo "${match}" | awk -F'=' '{print $2}') # read setting value
    value="${value:-$2}" # assign a default value if needed

    # remove / validate quotes
    left=$(echo "${value}" | cut -c1)
    right=$(echo "${value}" | rev | cut -c1)
    if [ "${left}" = "${right}" ]; then
        quote="${left}"
        value="${value%${quote}}"
        value="${value#${quote}}"
    elif [ "${left}" = "'" ] || [ "${left}" = "\"" ] || [ "${right}" = "'" ] || [ "${right}" = "\"" ]; then
        [ -n "${line}" ] && echo "Invalid character found in config file line ${line}: ${value}" || \
            echo "Invalid character found in default value for variable '$1': $2"
        return 1
    fi

    # write value to stdout
    printf "%s" "${value}"
    return 0
}

#=======================================================================================================================
# Initializes the global settings.
#=======================================================================================================================
# Globals:
#   - config_docker_working_dir
#   - config_docker_base_yml
#   - config_docker_prod_yml
#   - config_docker_dev_yml
#   - config_docker_service
#   - config_docker_platforms
# Arguments:
#   $1 - Base directory of the config gile.
# Outputs:
#   Initalized global config variables, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
init_config() {
    basedir="${1:-$PWD}"
    config_file="${basedir}/${DBM_CONFIG_FILE}"

    # initialize settings and/or default values 
    config_docker_working_dir=$(init_config_value 'DOCKER_WORKING_DIR' 'docker') || return 1
    config_docker_base_yml=$(init_config_value 'DOCKER_BASE_YML' 'docker-compose.yml') || return 1
    config_docker_prod_yml=$(init_config_value 'DOCKER_PROD_YML' 'docker-compose.prod.yml') || return 1
    config_docker_dev_yml=$(init_config_value 'DOCKER_DEV_YML' 'docker-compose.dev.yml') || return 1
    config_docker_service=$(init_config_value 'DOCKER_SERVICE_NAME' "${PWD##*/}") || return 1
    config_docker_platforms=$(init_config_value 'DOCKER_TARGET_PLATFORM' '') || return 1

    return 0
}

#=======================================================================================================================
# Reads all dependencies defined within the configuration file, identify by the pattern '^DBM_.*VERSION=.*'. Comments,
# trailing spaces, and protocols (http/https) are stripped. The function returns a single line of all identified
# dependencies as key-value pairs, separated by ';'. 
#=======================================================================================================================
# Outputs:
#   Initalized global config variables, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
read_dependencies() {
    [ ! -f "${config_file}" ] && return 1

    # retrieve all dependendencies from the DBM config file
    # remove all comments, trailing spaces, and protocols; separate each dependency by a ';'
    dependencies=$(grep '^DBM_.*VERSION=.*' "${config_file}" | sed 's/^DBM_//g;')
    dependencies=$(echo "${dependencies}" | sed 's/hub.docker.com\/r\//hub.docker.com\//g')
    dependencies=$(echo "${dependencies}" | sed 's/_VERSION=/ /g;s/\// /g;')
    dependencies=$(echo "${dependencies}" | sed -e 's/\s*#.*$//;s/[[:space:]]*$//;')
    dependencies=$(echo "${dependencies}" | sed -e 's/http:  //g;s/https:  //g;')
    printf "%s\n\n" "${dependencies}" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/;/g'
    return 0
}