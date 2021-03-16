#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
# readonly DOCKER_RUN='docker-compose'


#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Defines the command to generate a Docker compose file. The generated file merges all input files and substitutes all
# variables.
#=======================================================================================================================
# Arguments:
#   $1 - Docker Compose file flag(s), for example '-f docker-compose.yml -f docker-compose.dev.yml'
#   $2 - Optional tag to override default image tag.
# Outputs:
#   Writes config to stdout, or returns 1 on error.
#=======================================================================================================================
generate_config() {
    compose_files="$1"
    tag="$2"

    if ! config=$(eval "${DOCKER_RUN} ${compose_files} config"); then
        echo "${config}"
        return 1
    fi
    # fix incorrect CPU value (see https://github.com/docker/compose/issues/7771)
    config=$(echo "${config}" | sed -E "s/cpus: ([0-9\\.]+)/cpus: '\\1'/") || return 1

    # replace tag if applicable
    if [ -n "${tag}" ]; then
        escaped_tag=$(escape_string "${tag}")
        config=$(echo "${config}" | sed -E "s|^    image: .*|    image: ${escaped_tag}|g") || return 1
    fi

    echo "${config}"
}

#=======================================================================================================================
# Generates a temporary Docker Compose configuration file and returns the filename.
#=======================================================================================================================
#   $1 - Docker Compose file flag(s), for example '-f docker-compose.yml -f docker-compose.dev.yml'
#   $2 - Optional filename, replaced with temporary name if omitted
#   $3 - Name of the Docker Stack service
# Outputs:
#   Temporary Docker Compose configuration file; returns the filename.
#=======================================================================================================================
generate_config_file() {
    compose_files="$1"
    config_file="$2"
    service="$3"

    [ -z "${config_file}" ] && config_file=$(mktemp -t "dbm_temp.XXXXXXXXX")
    if ! config=$(generate_config "${compose_files}"); then
        echo "Cannot generate Docker Compose file: ${config_file}; error='${config}'"
        return 1
    else
        printf '%s' "${config}" > "${config_file}"
    fi
    
    echo "${config_file}"
    return 0
}

#=======================================================================================================================
# Parses a given Docker Compose configuration file (YML) and displays the referenced images. The images are filtered for
# provided services, if applicable.
#=======================================================================================================================
# Arguments:
#   $1 - Filename of the Docker Compose configuration.
#   $2 - Targeted services, separated by spaces.
# Outputs:
#   Writes targeted image information to stdout, returns 1 in case of errors.
#=======================================================================================================================
# shellcheck disable=SC2059
list_images() {
    config_file="$1"
    services="$2"
    images=''

    # Parse the generated Docker Compose file
    yaml=$(parse_yaml "${config_file}") || { echo "Cannot parse configuration file: ${config_file}"; return 1; }
    
    # Show targeted images information, filtered for services if applicable
    if [ -n "${services}" ] ; then
        for service in $services; do
            image=$(echo "${yaml}" | grep "^services_${service}_image=" | sed 's/^services_/ /' | sed 's/=/: /')
            [ -z "${image}" ] && echo "Service '${service}' not found" && return 1
            name=$(echo "${image}" | awk -F'"' '{print $2}')
            images="${images}${name}\n"
        done
    else
        targets=$(echo "${yaml}" | grep "_image=" | sed 's/^services_/ /')
        name=$(echo "${targets}" | awk -F'"' '{print $2}')
        images="${name}\n"
    fi

    printf "${images}"
    return 0
}
