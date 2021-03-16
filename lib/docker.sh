#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly DOCKER_EXEC='docker exec -it'
readonly DOCKER_RUN='docker-compose'
readonly DOCKER_BUILDX='docker buildx'
readonly DBM_BUILDX_BUILDER='dbm_buildx'


#=======================================================================================================================
# Functions
#=======================================================================================================================

bring_container_down() {
    # init arguments
    compose_file="$1"
    services="$2"

    eval "${DOCKER_RUN} -f '${compose_file}' down ${services}" && return 0 || return 1
}

#=======================================================================================================================
# Run a Docker image as container.
#=======================================================================================================================
# Arguments:
#   $1 - Docker Compose configuration file
#   $2 - Services
#   $3 - detached
#   $4 - terminal
# Outputs:
#   New Docker container, terminates on error.
#=======================================================================================================================
bring_container_up() {
    compose_file="$1"
    services="$2"
    detached="$3"
    terminal="$4"
    shell="$5"

    # define base command and flags
    base_cmd="${DOCKER_RUN} -f '${compose_file}'"
    [ "${detached}" = 'true' ] && flags=' -d' || flags='' 

    # bring container up
    eval "${base_cmd} up ${flags} --remove-orphans ${services}" || return 1

    # start terminal if applicable
    if [ "${terminal}" = 'true' ] ; then
        id=$(eval "${base_cmd} ps -q ${services}")
        # shellcheck disable=SC2181
        { [ "$?" != 0 ] || [ -z "${id}" ]; } && echo "Container ID not found" && return 1
        count=$(echo "${id}" | wc -l)
        [ "${count}" -gt 1 ] && echo "Terminal supports one container only" && return 1
        eval "${DOCKER_EXEC} ${id} ${shell}" # start shell terminal
    fi

    # bring container down when done and not detached or if in terminal mode
    { [ "${detached}" = 'false' ] || [ "${terminal}" = 'true' ]; } && \
        bring_container_down "${compose_file}" "${services}"
}

build_cross_platform_image() {
    # init arguments
    compose_file="$1"
    services="$2"
    no_cache="$3"
    docker_platforms="$4"

    # init buildx builder if needed
    available=$(eval "${DOCKER_BUILDX} ls | grep ${DBM_BUILDX_BUILDER}")
    if [ -z "${available}" ]; then
        log "Initializing buildx builder '${DBM_BUILDX_BUILDER}'"
        eval "${DOCKER_BUILDX} create --name '${DBM_BUILDX_BUILDER}' > /dev/null" || \
            { echo "Cannot create buildx instance"; return 1; }
    fi

    # use the dedicated buildx builder
    eval "${DOCKER_BUILDX} use '${DBM_BUILDX_BUILDER}'" || { echo "Cannot use buildx instance"; return 1; }

    # set the build command
    # TODO: check if TARGET can be used for SERVICES
    base_cmd="${DOCKER_BUILDX} bake -f '${compose_file}' --push --set '*.platform=${docker_platforms}'"

    [ "${no_cache}" = 'true' ] && base_cmd="${base_cmd} --no-cache"
    eval "${base_cmd}" || return 1

    # restore builder instance
    eval "${DOCKER_BUILDX} use default"
}


build_image() {
    # init arguments
    compose_file="$1"
    services="$2"
    no_cache="$3"

    cmd="${DOCKER_RUN} -f ${compose_file} build ${services}"
    [ "${no_cache}" = 'true' ] && base_cmd="${cmd} --no-cache"
    eval "${cmd}" && return 0 || return 1
}


deploy_stack() {
    # init arguments
    compose_file="$1"
    service_name="$2"

    eval "docker stack deploy -c ${compose_file} ${service_name}" && return 0 || return 1
}


#=======================================================================================================================
# Returns the CPU architecture of the Docker Engine. If unavailable, the architecture of the host is returned instead.
# The architecture 'x86_64' is converted to 'amd64' for compatibility with the buildx plugin.
#=======================================================================================================================
# Outputs:
#   Architecture of the Docker Engine if available, the host system otherwise.
#=======================================================================================================================
get_arch() {
    host_arch=$(docker info 2> /dev/null | grep Architecture | awk -F': ' '{print $2}')
    [ -z "${host_arch}" ] && host_arch=$(uname -m)
    echo "${host_arch}" | sed 's/x86_64/amd64/'
}

#=======================================================================================================================
# Returns the Operating System (OS) of the Docker Engine. If unavailable, the OS of the host is returned instead. On
# certain systems like macOS and Windows, the Docker Engine runs within a Virtual Machine (VM) instead of directly on
# the host system. In this situation, the function get_os() returns the OS of the VM to correctly evaluate the platform
# capability of the buildx plugin.
#=======================================================================================================================
# Outputs:
#   OS of the Docker Engine's VM if applicable, the host system otherwise.
#=======================================================================================================================
get_os() {
    host_os=$(docker info 2> /dev/null | grep OSType | awk -F': ' '{print $2}')
    [ -z "${host_os}" ] && host_os=$(uname -s)
    echo "${host_os}"
}

push_image() {
    # init arguments and variables
    images="$1"
    result=0

    for image in $images; do
        match=$(echo "${image}" | sed 's/:/.*/g')
        if docker image ls | grep -qE "${match}"; then
            log "Pushing image to registry: ${image}"
            docker push "${image}"
        else
            log "WARN: Cannot push, image not found: ${image}"
            result=1
        fi
    done

    return "${result}"
}

stop_container() {
    # init arguments
    compose_file="$1"
    services="$2"

    # execute the Docker command
    eval "${DOCKER_RUN} -f '${compose_file}' stop ${services}" && return 0 || return 1
}

#=======================================================================================================================
# Validates if all target platforms are supported by buildx. It also checks if the Docker Buildx plugin itself is
# present.
#=======================================================================================================================
# Arguments:
#   $1 - Target platforms to test, comma separated.
# Outputs:
#   Returns 0 if valid and returns 1 if invalid. It writes an error to stdout if applicable.
#=======================================================================================================================
validate_platforms() {
    platforms="$1,"

    # Validate Docker Buildx plugin is present
    if ! docker info | grep -q buildx; then
        echo "Docker Buildx plugin required"
        return 1
    fi

    # Identify supported platforms
    supported=$(eval "${DOCKER_BUILDX} inspect default | grep 'Platforms:' | sed 's/^Platforms: //g'")
    if [ -z "${supported}" ]; then
        echo "No information about supported platforms found"
        return 1
    fi

    # Validate if all platforms are supported
    missing=''
    IFS=',' # initialize platforms separator
    for item in $platforms; do
        if ! echo "${supported}," | grep -q "${item},"; then
            missing="${missing}${item}, "
        fi
    done

    # Return missing platforms, if any
    if [ -n "${missing}" ]; then
        echo "Target platforms not supported: ${missing}" | sed 's/, $//g' # remove trailing ', '
        return 1
    else
        return 0
    fi
}