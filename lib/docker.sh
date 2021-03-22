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
# Defines the platforms supported by Docker buildx and the registry manifest
# See 'platform' in https://docs.docker.com/registry/spec/manifest-v2-2/#manifest-list
# Derived from '$GOOS and $GOARCH' in https://golang.org/doc/install/source#environment
readonly SUPPORTED_PLATFORMS=\
"aix/ppc64
android/386
android/amd64
android/arm
android/arm64
darwin/amd64
darwin/arm64
dragonfly/amd64
freebsd/386
freebsd/amd64
freebsd/arm
illumos/amd64
ios/arm64
js/wasm
linux/386
linux/amd64
linux/arm
linux/arm64
linux/ppc64
linux/ppc64le
linux/mips
linux/mipsle
linux/mips64
linux/mips64le
linux/riscv64
linux/s390x
netbsd/386
netbsd/amd64
netbsd/arm
openbsd/386
openbsd/amd64
openbsd/arm
openbsd/arm64
plan9/386
plan9/amd64
plan9/arm
solaris/amd64
windows/386
windows/amd64"

# Derived from SUPPORTED_PLATFORMS: echo "${SUPPORTED_PLATFORMS}" | grep -o '/\S*$' | sed 's|/||g' | sort -u
readonly SUPPORTED_ARCH=\
"386
amd64
arm
arm64
mips
mips64
mips64le
mipsle
ppc64
ppc64le
riscv64
s390x
wasm"

# Derived from SUPPORTED_PLATFORMS: echo "${SUPPORTED_PLATFORMS}" | grep -o '^\S*/' | sed 's|/||g' | sort -u
readonly SUPPORTED_OS=\
"aix
android
darwin
dragonfly
freebsd
illumos
ios
js
linux
netbsd
openbsd
plan9
solaris
windows"

#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Brings a running Docker container down for the targeted environment. Once stopped, the container and related networks
# are removed. The referenced image(s) are untouched. It does not stop or remove deployed Docker Stack services. By
# convention, all running containers referencing to a service defined in the specified Docker Compose file are stopped.
#=======================================================================================================================
# Arguments:
#   $1 - Docker Compose configuration file.
# Outputs:
#   Stopped Docker container, terminates on error.
#=======================================================================================================================
bring_container_down() {
    # init arguments
    compose_file="$1"

    eval "${DOCKER_RUN} -f '${compose_file}' down" && return 0 || return 1
}

#=======================================================================================================================
# Initiates and starts the containers for the targeted environment. The referenced images need to be available either
# locally or remotely. Build the images prior to the up operation if needed.
#=======================================================================================================================
# Arguments:
#   $1 - Docker Compose configuration file.
#   $2 - Services to bring up.
#   $3 - Flag to run container in detached mode (defaults to 'false')
#   $4 - Flag to run container in terminal mode (defaults to 'false')
#   $5 - Specific terminal shell to run (defaults to 'sh')
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
        bring_container_down "${compose_file}"

    return 0
}

#=======================================================================================================================
# Builds a multi-architecture image instead of a regular image. The resulting image(s) are pushed to a central Docker
# registry (typically docker.io). The build command invokes Docker buildx, which needs to be enabled on the host (and is
# currently an experimental Docker feature).
#=======================================================================================================================
# Arguments:
#   $1 - Docker Compose configuration file.
#   $2 - Services to build (defaults to all).
#   $3 - Flag to build image without using cache (defaults to 'false')
#   $4 - Comma-separated target platforms, e.g. 'linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64'
# Outputs:
#   New Docker image(s) pushed to Docker registry, terminates on error.
#=======================================================================================================================
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
    base_cmd="${DOCKER_BUILDX} bake -f '${compose_file}' --push --set '*.platform=${docker_platforms}' ${services}"

    [ "${no_cache}" = 'true' ] && base_cmd="${base_cmd} --no-cache"
    eval "${base_cmd}" || return 1

    # restore builder instance
    eval "${DOCKER_BUILDX} use default"
}

#=======================================================================================================================
# Builds regular image(s) and store them locally. Use the 'services' argument to build selected images only.
#=======================================================================================================================
# Arguments:
#   $1 - Docker Compose configuration file.
#   $2 - Services to build (defaults to all).
#   $3 - Flag to build image without using cache (defaults to 'false')
#   $4 - Comma-separated target platforms, e.g. 'linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64'
# Outputs:
#   New Docker image(s) built locally, terminates on error.
#=======================================================================================================================
build_image() {
    # init arguments
    compose_file="$1"
    services="$2"
    no_cache="$3"

    cmd="${DOCKER_RUN} -f ${compose_file} build ${services}"
    [ "${no_cache}" = 'true' ] && base_cmd="${cmd} --no-cache"
    eval "${cmd}" && return 0 || return 1
}

#=======================================================================================================================
# Deploys the defined services as a Docker Stack. The referenced images need to be available either locally or remotely.
# Build the images prior to the deploy operation if needed.
#=======================================================================================================================
# Arguments:
#   $1 - Docker Compose configuration file.
#   $2 - Service name to use for the Docker stack.
# Outputs:
#   New Docker image(s) built locally, terminates on error.
#=======================================================================================================================
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

#=======================================================================================================================
# Validates if a given CPU architecture is supported by Docker. The validation is case sensitive. See 
# is_valid_platform() for more details.
#=======================================================================================================================
# Arguments:
#   $1 - Architecture to validate, e.g. 'amd64'.
# Outputs:
#   Return 0 is valid, returns 1 otherwise.
#=======================================================================================================================
is_valid_arch() {
    [ -n "$1" ] && arch="$1" || return 1
    echo "${SUPPORTED_ARCH}" | grep -q "^${arch}\$"
}

#=======================================================================================================================
# Validates if a given OS is supported by Docker. The validation is case sensitive. See is_valid_platform() for more
# details.
#=======================================================================================================================
# Arguments:
#   $1 - Architecture to validate, e.g. 'amd64'.
# Outputs:
#   Return 0 is valid, returns 1 otherwise.
#=======================================================================================================================
is_valid_os() {
    [ -n "$1" ] && os="$1" || return 1
    echo "${SUPPORTED_OS}" | grep -q "^${os}\$"
}

#=======================================================================================================================
# Validates if a given platform is supported by Docker. The platform consists of the operating system and the CPU
# architecture. The validation is case sensitive. 
# See https://docs.docker.com/registry/spec/manifest-v2-2/#manifest-list for more details.
#=======================================================================================================================
# Arguments:
#   $1 - Platform to validate, e.g. 'linux/amd64'.
# Outputs:
#   Return 0 is valid, returns 1 otherwise.
#=======================================================================================================================
is_valid_platform() {
    [ -n "$1" ] && platform="$1" || return 1
    echo "${SUPPORTED_PLATFORMS}" | grep -q "^${platform}\$"
}

#=======================================================================================================================
# Pushes locally built images to a central Docker repository (typically docker.io). 
#=======================================================================================================================
# Arguments:
#   $1 - Images to push, separated by a newline '\n'.
# Outputs:
#   Docker image(s) pushed to registry, terminates on error.
#=======================================================================================================================
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
            warn "Cannot push, image not found: ${image}"
            result=1
        fi
    done

    return "${result}"
}

#=======================================================================================================================
# Pauses the execution of running Docker containers for the targeted environment. It does not stop or remove deployed
# Docker Stack services.
#=======================================================================================================================
# Arguments:
#   $1 - Docker Compose configuration file.
#   $2 - Services to stop (defaults to all).
# Outputs:
#   Stopped Docker containers, terminates on error.
#=======================================================================================================================
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