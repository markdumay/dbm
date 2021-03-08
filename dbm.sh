#!/bin/sh

#=======================================================================================================================
# Title         : dbm.sh
# Description   : Helper script to manage Docker images
# Author        : Mark Dumay
# Date          : March 7th, 2021
# Version       : 0.6.5
# Usage         : ./dbm.sh [OPTIONS] COMMAND
# Repository    : https://github.com/markdumay/dbm.git
# License       : Copyright © 2021 Mark Dumay. All rights reserved.
#                 Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
# Comments      : 
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly RED='\e[31m' # Red color
readonly NC='\e[m'    # No color / reset
readonly BOLD='\e[1m' # Bold font
readonly DBM_CONFIG_FILE='dbm.ini'
readonly DOCKER_RUN='docker-compose'
readonly DOCKER_BUILDX='docker buildx'
readonly DBM_BUILDX_BUILDER='dbm_buildx'
readonly DOCKER_EXEC='docker exec -it'
readonly DOCKER_API='https://hub.docker.com/v2'
readonly GITHUB_API="https://api.github.com"
readonly DOCKER_API_PAGE_SIZE=100 # Limit Docker API results to the first 100 only
readonly VERSION_REGEX='([vV])?[0-9]+\.[0-9]+(\.[0-9]+)?' #  MAJOR.MINOR required, 'v' and PATCH are optional


#=======================================================================================================================
# Variables
#=======================================================================================================================
detached='false'
no_cache='false'
tag=''
push='false'
config_file=''
terminal='false'
multi_architecture='false'
images=''
command=''
services=''
subcommand=''
docker_base=''
docker_prod=''
docker_dev=''
docker_platforms=''
docker_service=''
script_version=''


#=======================================================================================================================
# Helper Functions
#=======================================================================================================================

#=======================================================================================================================
# Display usage message.
#=======================================================================================================================
# Globals:
#   - backup_dir
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage() { 
    echo "Helper script to manage Docker images"
    echo 
    echo "Usage: $0 COMMAND [SUBCOMMAND] [OPTIONS] [SERVICE...]" 
    echo
    echo "Commands:"
    echo "  prod                        Target a production image"
    echo "  dev                         Target a development image"
    echo "  check                       Check for dependency upgrades"
    echo "  version                     Show version information"
    echo
    echo "Subcommands (prod and dev):"
    echo "  build                       Build a Docker image"
    echo "  config <OUTPUT>             Generate a merged Docker Compose file"
    echo "  deploy                      Deploy the image(s) as Docker Stack service(s)"
    echo "  down                        Stop a running container and remove defined containers/networks"
    echo "  up                          Run a Docker image as container"
    echo "  stop                        Stop a running container"
    echo
    echo "Options (up only):"
    echo "  -d, --detached              Run in detached mode"
    echo "  -t, --terminal              Run in detached mode and start terminal (if supported by image)"
    echo
    echo "Options (build only):"
    echo "  --no-cache                  Do not use cache when building the image"
    echo "  --push                      Push image to Docker Registry"
    echo "  --platforms <PLATFORMS...>  Enabled multi-architecture platforms (comma separated)"
    echo
    echo "Options (prod and dev only):"
    echo "  --tag <TAG>                 Override build tag"
    echo
}

#=======================================================================================================================
# Displays error message on console and terminates with non-zero error.
#=======================================================================================================================
# Arguments:
#   $1 - Error message to display.
# Outputs:
#   Writes error message to stderr, non-zero exit code.
#=======================================================================================================================
terminate() {
    printf "${RED}${BOLD}%s${NC}\n" "ERROR: $1"
    exit 1
}

#=======================================================================================================================
# Print current progress on console.
#=======================================================================================================================
# Arguments:
#   $1 - Progress message to display.
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
print_status() {
    printf "${BOLD}%s${NC}\n" "$1"
}

#=======================================================================================================================
# Log a message on console.
#=======================================================================================================================
# Arguments:
#   $1 - Log message to display.
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
log() {
    echo "$1"
}

#======================================================================================================================
# Asks the user to confirm the operation.
#======================================================================================================================
# Outputs:
#   Exits with a zero error code if the user does not confirm the operation.
#======================================================================================================================
confirm_operation() {
    while true; do
        printf "Are you sure you want to continue? [y/N] "
        read -r yn
        yn=$(echo "${yn}" | tr '[:upper:]' '[:lower:]')

        case "${yn}" in
            y | yes )     break;;
            n | no | "" ) exit;;
            * )           echo "Please answer y(es) or n(o)";;
        esac
    done
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

#=======================================================================================================================
# Validates if all target platforms are supported by buildx. It also checks if the Docker Buildx plugin itself is
# present.
#=======================================================================================================================
# Arguments:
#   $1 - Target platforms to test, comma separated.
# Outputs:
#   Returns 0 if valid and returns 1 if not valid and writes an error to stdout if applicable.
#=======================================================================================================================
validate_platforms() {
    # validate Docker Buildx plugin is present
    if ! docker info | grep -q buildx; then
        echo "Docker Buildx plugin required"
        return 1
    fi

    # validate if all platforms are supported
    platforms="$1,"
    supported=$(eval "${DOCKER_BUILDX} inspect default | grep 'Platforms:' | sed 's/^Platforms: //g'")
    if [ -z "${supported}" ]; then
        echo "No information about supported platforms found"
        return 1
    fi
    missing=''
    IFS=',' # initialize platforms separator
    for item in $platforms; do
        if ! echo "${supported}," | grep -q "${item},"; then
            missing="${missing}${item}, "
        fi
    done

    # return missing platforms, if any
    if [ -n "${missing}" ]; then
        echo "One or more target platforms not supported: ${missing}" | sed 's/, $//g' # remove trailing ', '
        return 1
    else
        return 0
    fi
}

#=======================================================================================================================
# Parse and validate the command-line arguments.
#=======================================================================================================================
# Globals:
#   - command
#   - detached
#   - services
#   - subcommand
#   - terminal
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
parse_args() {
    subcommand=''

    # Process and validate command-line arguments
    while [ -n "$1" ]; do
        case "$1" in
            -d | --detached)                   detached='true';;
            --no-cache)                        no_cache='true';;
            --push)                            push='true';;
            --platforms)                       shift; docker_platforms="$1";;
            --tag)                             shift; tag="$1";;
            -t | --terminal)                   terminal='true';;
            dev | prod | check | version)      command="$1";;
            build | deploy | down | stop | up) subcommand="$1";;
            config )                           subcommand="$1"; shift; config_file="$1";;
            * )                                services="${services} $1"
        esac
        [ -n "$1" ] && shift
    done

    # Validate arguments
    fatal_error=''
    warning=''
    prefix=$(echo "${services}" | cut -c1)
    service_count=$(echo "${services}" | wc -w)
    # Requirement 1 - A single value command is provided
    if [ -z "${command}" ]; then fatal_error="Expected command"
    # Requirement 2 - No subcommand, flags, or services is defined for the command 'version', 'check', or 'config'
    elif { [ "${command}" = 'version' ] || [ "${command}" = 'check' ] || [ "${command}" = 'config' ]; } && 
         [ -n "${subcommand}" ] && \
         [ -n "${services}" ] && \
         [ "${detached}" != 'false' ] && \
         [ "${terminal}" != 'false' ]; then fatal_error="Invalid arguments"
    # Requirement 3 - A subcommand is provided for 'prod' and 'dev'
    elif { [ "${command}" = 'prod' ] || [ "${command}" = 'dev' ]; } && [ -z "${subcommand}" ]
        then fatal_error="Expected subcommand"
    # Requirement 4 - At most one service is defined in terminal mode
    elif [ "${terminal}" = 'true' ] && \
         [ "${service_count}" -gt 1 ]; then 
         fatal_error="Terminal mode supports one service only"
    # Requirement 5 - At most one service is defined when specifying a tag
    elif [ -n "${tag}" ] && \
         [ "${service_count}" -gt 1 ]; then 
         fatal_error="Tag supports one service only"
    # Warning 1 - Detached mode is not supported in terminal mode
    elif [ "${detached}" = 'true' ] && \
         [ "${terminal}" = 'true' ]; then
        warning="Ignoring detached mode argument"
    # Warning 2 - No-cache, push, and platforms not supported for subcommands other than build
    elif { [ "${no_cache}" = 'true' ] || [ "${push}" = 'true' ] || [ -n "${docker_platforms}" ]; } && \
         [ "${subcommand}" != 'build' ]; then
        warning="Ignoring build arguments"
    # Warning 3 - Platforms not supported without push
    elif [ "${push}" = 'false' ] && [ -n "${docker_platforms}" ]; then
        warning="Ignoring platforms argument"
        docker_platforms=''
    # Warning 4 - Tag not supported for commands other than dev and prod
    elif [ -n "${tag}" ] && [ "${command}" != 'prod' ] && [ "${command}" != 'dev' ]; then
        warning="Ignoring tag"
        tag=''
    # Requirement 6 - Output file is required for config command
    elif [ "${subcommand}" = 'config' ] && [ -z "${config_file}" ]; then 
        fatal_error="Output file required"
    # Requirement 7 - Services do not start with '-' character
    elif [ "${prefix}" = "-" ]; then fatal_error="Invalid option"
    fi
    
    # Standardize arguments
    [ "${terminal}" = 'true' ] && detached='true'
    [ "${push}" = 'true' ] && [ -n "${docker_platforms}" ] && multi_architecture='true'
    services=$(echo "${services}" | awk '{gsub(/^ +| +$/,"")} {print $0}') # remove spaces

    # Validate buildx support for targeted platforms
    if [ -z "${fatal_error}" ] && [ "${multi_architecture}" = 'true' ]; then
        fatal_error=$(validate_platforms "${docker_platforms}")
    fi

    # Inform user and terminate on fatal error
    [ -n "${fatal_error}" ] && usage && terminate "${fatal_error}"
    [ -n "${warning}" ] && [ "${command}" != 'check' ] && [ "${command}" != 'version' ] && log "WARN: ${warning}"
}

#=======================================================================================================================
# Parse a YAML file into a flat list of variables.
#=======================================================================================================================
# Source: https://gist.github.com/briantjacobs/7753bf850ca5e39be409
# Arguments:
#   $1 - YAML file to use as input
# Outputs:
#   Writes flat variable list to stdout, returns 1 if not successful
#=======================================================================================================================
parse_yaml() {
    [ ! -f "$1" ] && return 1
    
    s='[[:space:]]*'
    w='[a-zA-Z0-9_]*'
    fs="$(echo @|tr @ '\034')"
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" 2> /dev/null \
        -e "s|^\($s\)\($w\)${s}[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$1" 2> /dev/null |
    awk -F"$fs" '{
    indent = length($1)/2;
    vname[indent] = $2;
    for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s=\"%s\"\n", vn, $2, $3);
        }
    }' | sed 's/_=/+=/g'
}

#=======================================================================================================================
# Display time elapsed in a user-friendly way. For example:
#   $ display_time 11617: 3 hours 13 minutes and 37 seconds
#   $ display_time 42: 42 seconds
#   $ display_time 662: 11 minutes and 2 seconds
#=======================================================================================================================
# Arguments:
#   $1 - Time in seconds
# Outputs:
#   Writes user-friendly time to stdout if applicable.
#=======================================================================================================================
display_time() {
    t=$1
    d=$((t/60/60/24))
    h=$((t/60/60%24))
    m=$((t/60%60))
    s=$((t%60))
    [ "${d}" -gt 0 ] && printf '%d days ' "${d}"
    [ "${h}" -gt 0 ] && printf '%d hours ' "${h}"
    [ "${m}" -gt 0 ] && printf '%d minutes ' "${m}"
    [ "${d}" -gt 0 ] || [ $h -gt 0 ] || [ $m -gt 0 ] && printf 'and '
    [ "${s}" = 1 ] && printf '%d second' "${s}" || printf '%d seconds' "${s}"
}

#=======================================================================================================================
# Reads all key/value pairs beginning with 'DBM_*' from the default config file. The output is written to stdout with
# the prefix 'export ' for each line.
#=======================================================================================================================
# Outputs:
#   Writes matching key/value pairs to stdout.
#=======================================================================================================================
# shellcheck disable=SC2059
export_env_values() {
    # retrieve all custom variables from the DBM config file
    # remove all comments and trailing spaces; separate each dependency by a ';'
    vars=$(grep '^DBM_.*=.*' "${DBM_CONFIG_FILE}" | sed 's/^DBM_//g')
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
            terminate "Invalid entry in '${DBM_CONFIG_FILE}': ${item}"
        fi
    done

    printf "${results}"
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
    match=$(grep -in "^$1=" "${DBM_CONFIG_FILE}" 2> /dev/null) # read entry from config file
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
        [ -n "${line}" ] && terminate "Invalid character found in config file line ${line}: ${value}"
        terminate "Invalid character found in default value for variable '$1': $2"
    fi

    # write value to stdout
    printf "%s" "${value}"
}

#=======================================================================================================================
# Initializes the global settings.
#=======================================================================================================================
# Globals:
#   - docker_base
#   - docker_prod
#   - docker_dev
#   - docker_stack
#   - script_version
# Outputs:
#   Initalized global variables, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
init_config() {
    # initialize settings and/or default values 
    [ ! -f "${DBM_CONFIG_FILE}" ] && log "WARN: Config file '${DBM_CONFIG_FILE}' not found, using default values"
    docker_working_dir=$(init_config_value 'DOCKER_WORKING_DIR' 'docker')
    docker_base_yml=$(init_config_value 'DOCKER_BASE_YML' 'docker-compose.yml')
    docker_prod_yml=$(init_config_value 'DOCKER_PROD_YML' 'docker-compose.prod.yml')
    docker_dev_yml=$(init_config_value 'DOCKER_DEV_YML' 'docker-compose.dev.yml')
    docker_service=$(init_config_value 'DOCKER_SERVICE_NAME' "${PWD##*/}")
    docker_platforms=$(init_config_value 'DOCKER_TARGET_PLATFORM' '')
    
    # set the Docker command arguments
    docker_base="-f ${docker_base_yml}"
    docker_prod="${docker_base} -f ${docker_prod_yml}"
    docker_dev="${docker_base} -f ${docker_dev_yml}"

    # init script version info
    script_dir=$(dirname "$0")
    script_version=$(cat "${script_dir}/VERSION" 2> /dev/null)
    script_version="${script_version:-unknown}"
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
# Defines the command to generate a Docker compose file. The generated file merges all input files and substitutes all
# variables.
#=======================================================================================================================
# Globals:
#   - base_cmd
#   - command
#   - docker_prod
#   - docker_dev
# Outputs:
#   Writes config to stdout, or returns 1 on error.
#=======================================================================================================================
generate_config() {
    [ "${command}" = 'dev' ] && base_cmd="${DOCKER_RUN} ${docker_dev}" ||
        base_cmd="${DOCKER_RUN} ${docker_prod}"
    config=$(eval "${base_cmd} config 2> /dev/null") || return 1
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
# Outputs:
#   Temporary Docker Compose configuration file; returns the filename.
#=======================================================================================================================
generate_temp_config_file() {
    temp_file=$(mktemp -t "${docker_service}.XXXXXXXXX")
    if ! generate_config > "${temp_file}"; then
        terminate "Cannot generate Docker Compose file: ${temp_file}"
    fi
    echo "${temp_file}"
}

#======================================================================================================================
# Retrieves the latest available tag from a GitHub repository. Release candidates are excluded by default.
#======================================================================================================================
# Arguments:
#   $1 - Repository owner.
#   $2 - Repository name.
#   $3 - Optional release extension.
# Outputs:
#   Latest available tag if found, empty string otherwise.
#======================================================================================================================
get_latest_github_tag() {
    owner="$1"
    repo="$2"
    extension=$(escape_string "$3")

    tag=$(curl -s "${GITHUB_API}/repos/${owner}/${repo}/releases/latest" | grep "tag_name" | awk -F'"' '{print $4}')
    echo "${tag}" | grep -Eo "^${VERSION_REGEX}${extension}$"
}

#======================================================================================================================
# Retrieves the latest available tag from the Docker Hub. Official Docker repository links are converted to input
# supported by the Docker registry API.
#======================================================================================================================
# Arguments:
#   $1 - Repository owner.
#   $2 - Repository name.
#   $3 - Optional release extension.
# Outputs:
#   Latest available tag if found, empty string otherwise.
#======================================================================================================================
get_latest_docker_tag() {
    [ "$1" = "_" ] && owner='library' || owner="$1" # Update owner of official Docker repositories
    repo="$2"
    extension=$(escape_string "$3")

    url="${DOCKER_API}/repositories/${owner}/${repo}/tags/?page_size=${DOCKER_API_PAGE_SIZE}"
    tags=$(curl -s "${url}")
    tags=$(echo "${tags}" | jq -r '.results|.[]|.name' | grep -E "^${VERSION_REGEX}${extension}$")
    echo "${tags}" | sort --version-sort | tail -n1
}

#======================================================================================================================
# Expands a version string if MINOR or PATCH are omitted. The version string should start with MAJOR, 'v' or 'V' 
# prefixes are not supported. For example, the input '1.1' is converted to '1.1.0'.
#======================================================================================================================
# Arguments:
#   $1 - Repository owner.
#   $2 - Optional extension.
# Outputs:
#   A version string conforming to <MAJOR>.<MINOR>.<PATCH><EXTENSION>.
#======================================================================================================================
expand_version() {
    if echo "$1" | grep -qEo "^[0-9]+$"; then
        echo "$1.0.0$2"
    elif echo "$1" | grep -qEo "^[0-9]+.[0-9]+$"; then
        echo "$1.0$2"
    else
        echo "$1$2"
    fi
}


#=======================================================================================================================
# Workflow Functions
#=======================================================================================================================

#=======================================================================================================================
# Build a Docker image.
#=======================================================================================================================
# Globals:
#   - command
#   - docker_dev
#   - docker_prod
#   - docker_platforms
#   - no_cache
#   - services
# Outputs:
#   New Docker image, terminates on error.
#=======================================================================================================================
execute_build() {
    print_status "Building images"

    # generate a temporary Docker Compose file
    temp_file=$(generate_temp_config_file)

    # init regular build
    if [ "${multi_architecture}" != 'true' ]; then
        log "Initializing regular build"
        base_cmd="${DOCKER_RUN} -f ${temp_file} build ${services}"
    # init multi-architecture build
    else
        log "Initializing multi-architecture build"
        display_platforms=$(echo "${docker_platforms}" | sed 's/,/, /g' )
        log "Targeted platforms: ${display_platforms}"
        # init buildx builder if needed
        available=$(eval "${DOCKER_BUILDX} ls | grep ${DBM_BUILDX_BUILDER}")
        if [ -z "${available}" ]; then
            log "Initializing buildx builder '${DBM_BUILDX_BUILDER}'"
            eval "${DOCKER_BUILDX} create --name '${DBM_BUILDX_BUILDER}' > /dev/null" || \
                terminate "Cannot create buildx instance"
        fi
        # use the dedicated buildx builder
        eval "${DOCKER_BUILDX} use '${DBM_BUILDX_BUILDER}'" || terminate "Cannot use buildx instance"
        # set the build command
        base_cmd="${DOCKER_BUILDX} bake -f '${temp_file}' --push --set '*.platform=${docker_platforms}'"
    fi

    # time and execute the build
    t1=$(date +%s)
    [ "${no_cache}" = 'true' ] && base_cmd="${base_cmd} --no-cache"
    eval "${base_cmd}" || terminate "Could not complete build"
    t2=$(date +%s)
    elapsed_string=$(display_time $((t2 - t1)))
    [ "${t2}" -gt "${t1}" ] && log "Total build time ${elapsed_string}"

    # push regular images to registry if applicable
    if [ "${multi_architecture}" != 'true' ] && [ "${push}" = 'true' ] && [ -n "${images}" ]; then
        for image in $images; do
            match=$(echo "${image}" | sed 's/:/.*/g')
            if docker image ls | grep -qE "${match}"; then
                log "Pushing image to registry: ${image}"
                docker push "${image}"
            else
                log "WARN: Cannot push, image not found: ${image}"
            fi
        done
    fi

    # restore builder instance if applicable
    if [ -n "${docker_platforms}" ]; then
        eval "${DOCKER_BUILDX} use default"
    fi

    # clean up temporary files
    if [ -n "${temp_file}" ]; then
        rm -f "${temp_file}" || true
    fi
}

#=======================================================================================================================
# Generate a Docker Compose file.
#=======================================================================================================================
# Globals:
#   - config_file
# Outputs:
#   Docker Compose file.
#=======================================================================================================================
execute_config() {
    print_status "Generating Docker Compose file"

    # warn if output file exists
    if [ -f "${config_file}" ]; then
        echo
        echo "WARNING! The file '${config_file}' will be overwritten"
        echo
        confirm_operation
    fi
    
    # generate the config file
    if ! generate_config > "${config_file}"; then
        terminate "Cannot generate Docker Compose file: ${config_file}"
    fi
    log "Generated '${config_file}'"
}

#=======================================================================================================================
# Scans all dependencies identified by 'DBM_*_VERSION' in the default config file. The current version is compared to 
# the latest version available in the repository, if specified. The algorithm expects a semantic versioning pattern,
# following the pattern 'MAJOR.MINOR.PATCH' with a potential extension. The matching is not strict, as version strings
# consisting of only 'MAJOR' or 'MAJOR.MINOR' are also considered valid. A 'v' or 'V' prefix is optional.
#
# The format of a dependency takes the following form:
# 1) DBM_<IDENTIFIER>_VERSION=<MAJOR>[.MINOR][.PATCH][EXTENSION]
# 2) DBM_<IDENTIFIER>_VERSION=[{http|https}]<PROVIDER>[/r]/<OWNER>/<REPO> [{v|V}]<MAJOR>[.MINOR][.PATCH][EXTENSION]
#
# The following dependencies are some examples:
# - DBM_GOLANG_VERSION=https://hub.docker.com/_/golang 1.16-buster
# - DBM_ALPINE_GIT_VERSION=https://hub.docker.com/r/alpine/git v2.30
# - DBM_RESTIC_VERSION=github.com/restic/restic 0.12.0 # this is a comment
# - DBM_ALPINE_VERSION=3.12
#
# The following version strings are valid:
# - 1.14-buster            MAJOR='1', MINOR='14', EXTENSION='-buster'
# - 1.14.15                MAJOR='1', MINOR='14', PATCH='15'
# The following version strings are invalid:
# - alpine3.13             Starts with EXTENSION='alpine' instead of MAJOR
# - windowsservercore-1809 Starts with EXTENSION='windowsservercore' instead of MAJOR
#
# The outcome for each dependency can be one of the following:
# - No repository link, skipping
#   The dependency does not specify a repository, e.g. DBM_ALPINE_VERSION=3.12.
# - Malformed, skipping
#   At least one of the mandatory arguments PROVIDER, OWNER, REPO, or MAJOR is missing.
#   e.g. DBM_RESTIC_VERSION=github.com/restic 0.12.0
# - Provider not supported, skipping
#   The specified provider is not supported, currently only 'github.com' and 'hub.docker.com' are supported.
#   e.g. DBM_YAML_VERSION=gopkg.in/yaml.v2 v2.4.0
# - No tags found, skipping
#   The repository did not return any tags matching the (optional) extension.
# - Up to date
#   The current version is the latest.
# - Different version found
#   The repository returned a different version as latest (which might be newer).
#=======================================================================================================================
# Outputs:
#   Writes matching key/value pairs to stdout. Returns 1 in case of potential updates, 0 otherwise.
#=======================================================================================================================
# shellcheck disable=SC2059
execute_check_upgrades() {
    logs=''
    flag=0
    # retrieve all dependendencies from the DBM config file
    # remove all comments, trailing spaces, and protocols; separate each dependency by a ';'
    dependencies=$(grep '^DBM_.*VERSION=.*' "${DBM_CONFIG_FILE}" | sed 's/^DBM_//g;')
    dependencies=$(echo "${dependencies}" | sed 's/hub.docker.com\/r\//hub.docker.com\//g')
    dependencies=$(echo "${dependencies}" | sed 's/_VERSION=/ /g;s/\// /g;')
    dependencies=$(echo "${dependencies}" | sed -e 's/\s*#.*$//;s/[[:space:]]*$//;')
    dependencies=$(echo "${dependencies}" | sed -e 's/http:  //g;s/https:  //g;')
    dependencies=$(printf "${dependencies}\n\n" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/;/g')

    IFS=';' # initialize dependency separator
    width=0 # initialize tab width of first output column
    for item in $dependencies; do
        # initialize dependency provider, owner, repo, version, and extension
        # version information is always expanded to 'MAJOR.MINOR.PATCH', setting MINOR and PATCH to '0' if omitted
        name=$(echo "${item}" | awk -F' ' '{print $1}')
        provider=$(echo "${item}" | awk -F' ' '{print $2}' | tr '[:upper:]' '[:lower:]') # make case insensitive
        owner=$(echo "${item}" | awk -F' ' '{print $3}')
        repo=$(echo "${item}" | awk -F' ' '{print $4}')
        extension=$(echo "${item}" | awk -F' ' '{print $5}')
        version=$(echo "${extension}" | grep -Eo "^${VERSION_REGEX}")
        esc_version=$(escape_string "${version}")
        [ -n "${esc_version}" ] && extension=$(echo "${extension}" | sed "s/${esc_version}//g") # strip version information
        version=$(echo "${version}" | sed 's/^v//g;s/^V//g;')
        version=$(expand_version "${version}") # expand version info if needed with minor and patch
        count=$(echo "${item}" | wc -w) # identify number of parsed arguments (should be 2 or 5)
        [ "${count}" -eq 2 ] && version="${provider}" && extension=''
        dependency="[${name} v${version}${extension}]"
        curr_width=$(echo "${dependency}" | awk '{print length}') # set current tab width
        [ "${curr_width}" -gt "${width}" ] && width="${curr_width}" # update tab width if needed

        # validate number of arguments
        if [ "${count}" -eq 2 ]; then
            logs="${logs}${dependency}\t No repository link, skipping\n"
            continue
        elif [ "${count}" -ne 5 ]; then
            logs="${logs}[${name}]\t Malformed, skipping\n"
            continue
        fi
        
        # obtain latest tag from supported providers
        case "${provider}" in
            hub.docker.com )
                latest=$(get_latest_docker_tag "${owner}" "${repo}" "${extension}")
                ;;
            github.com )
                latest=$(get_latest_github_tag "${owner}" "${repo}" "${extension}")
                ;;
            * )
                logs="${logs}${dependency}\t Provider '${provider}' not supported, skipping\n"
                continue
        esac

        # compare latest tag to current tag
        latest_base=$(echo "${latest}" | sed "s/${extension}$//g;s/^v//g;s/^V//g;")
        latest_expanded=$(expand_version "${latest_base}" "${extension}")
        if [ -z "${latest}" ]; then
            logs="${logs}${dependency}\t No tags found, skipping\n"
        elif [ "${version}${extension}" = "${latest_expanded}" ]; then
            logs="${logs}${dependency}\t Up to date\n"
        else
            logs="${logs}${dependency}\t Different version found: '${latest}'\n"
            flag=1
        fi
    done

    # format and display findings
    width=$((width + 2))
    tabs "${width}"
    printf "${logs}"

    return "${flag}"
}

#=======================================================================================================================
# Deploy a Docker image as Docker Stack service(s).
#=======================================================================================================================
# Globals:
#   - docker_stack
# Outputs:
#   New Docker Stack service(s), terminates on error.
#=======================================================================================================================
execute_deploy() {
    print_status "Deploying Docker Stack services"
    fatal=''
    temp_file=$(generate_temp_config_file)
    base_cmd="docker stack deploy -c ${temp_file} ${docker_service}"
    eval "${base_cmd}" || fatal="Could not deploy services"

    # clean up temporary files
    if [ -n "${temp_file}" ]; then
        rm -f "${temp_file}" || true
    fi

    # terminate on fatal error
    [ -n "${fatal}" ] && terminate "${fatal}"
}

#=======================================================================================================================
# Stop a running container and remove defined containers/networks.
#=======================================================================================================================
# Globals:
#   - command
#   - docker_dev
#   - docker_prod
#   - services
# Outputs:
#   Removed Docker container, terminates on error.
#=======================================================================================================================
execute_down() {
    print_status "Bringing containers and networks down"
    fatal=''
    temp_file=$(generate_temp_config_file)
    base_cmd="${DOCKER_RUN} -f '${temp_file}' down"
    eval "${base_cmd} ${services}" || fatal="Could not bring down containers"

    # clean up temporary files
    if [ -n "${temp_file}" ]; then
        rm -f "${temp_file}" || true
    fi

    # terminate on fatal error
    [ -n "${fatal}" ] && terminate "${fatal}"
}

#=======================================================================================================================
# Run a Docker image as container.
#=======================================================================================================================
# Outputs:
#   New Docker container, terminates on error.
#=======================================================================================================================
execute_run() {
    print_status "Bringing containers and networks up"

    # define base command and flags
    temp_file=$(generate_temp_config_file)
        base_cmd="${DOCKER_RUN} -f '${temp_file}'"
    [ "${detached}" = 'true' ] && flags=' -d' || flags='' 

    # bring container up
    eval "${base_cmd} up ${flags} --remove-orphans ${services}" || terminate "Could not bring up containers"

    # start terminal if applicable
    if [ "${terminal}" = 'true' ] ; then
        id=$(eval "${base_cmd} ps -q ${services}")
        # shellcheck disable=SC2181
        { [ "$?" != 0 ] || [ -z "${id}" ]; } && terminate "Container ID not found"        
        count=$(echo "${id}" | wc -l)
        [ "${count}" -gt 1 ] && terminate "Terminal supports one container only"
        eval "${DOCKER_EXEC} ${id} sh" # start sh terminal
    fi

    # bring container down when done and not detached or if in terminal mode
    { [ "${detached}" = 'false' ] || [ "${terminal}" = 'true' ]; } && eval "${base_cmd} down"

    # clean up temporary files
    if [ -n "${temp_file}" ]; then
        rm -f "${temp_file}" || true
    fi
}

#=======================================================================================================================
# Stop a running container.
#=======================================================================================================================
# Outputs:
#   Stopped Docker container, terminates on error.
#=======================================================================================================================
execute_stop() {
    print_status "Stopping containers and networks"
    temp_file=$(generate_temp_config_file)
    base_cmd="${DOCKER_RUN} -f '${temp_file}' stop"
    eval "${base_cmd} ${services}" || fatal="Could not stop containers"

    # clean up temporary files
    if [ -n "${temp_file}" ]; then
        rm -f "${temp_file}" || true
    fi

    # terminate on fatal error
    [ -n "${fatal}" ] && terminate "${fatal}" 
}

#=======================================================================================================================
# Validate availability of Docker and Docker Compose. Show version information on console.
#=======================================================================================================================
# Outputs:
#   Writes version information to stdout, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
execute_validate_and_show_env() {
    print_status "Validating environment"

    # Detect current Docker version and Docker Compose version
    docker_version=$(docker -v 2>/dev/null | grep -Eo "[0-9]*.[0-9]*.[0-9]*," | cut -d',' -f 1)
    compose_version=$(docker-compose -v 2>/dev/null | grep -Eo "[0-9]*.[0-9]*.[0-9]*," | cut -d',' -f 1)
    [ "${docker_version}" = '' ] && terminate "Docker not found, is the daemon running?"
    [ "${compose_version}" = '' ] && terminate "Docker Compose not found"

    # Show environment information
    os=$(uname -s)
    arch=$(uname -m | sed 's/x86_64/amd64/')
    log "  Docker Engine:        v${docker_version}"
    log "  Docker Compose:       v${compose_version}"
    log "  Docker Build Manager: v${script_version}"
    log "  Host:                 ${os}/${arch}"
    echo
}

#=======================================================================================================================
# Validate Docker compose configuration. Show image information on console.
#=======================================================================================================================
# Globals:
#   - images
#   - services
# Outputs:
#   Writes targeted image information to stdout, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
execute_validate_and_show_images() {
    print_status "Identifying targeted images"

    # Generate temp Docker compose configuration
    temp_file=$(mktemp -t "${docker_service}.XXXXXXXXX")
    if ! generate_config > "${temp_file}"; then
        terminate "Cannot generate Docker Compose file: ${temp_file}"
    fi

    yaml=$(parse_yaml "${temp_file}")
    # shellcheck disable=SC2181
    [ "$?" -ne 0 ] && terminate "Cannot generate Docker compose configuration"
    
    # Show targeted images information, filtered for services if applicable
    if [ -n "${services}" ] ; then
        for service in $services; do
            image=$(echo "${yaml}" | grep "^services_${service}_image=" | sed 's/^services_/  /' | sed 's/=/: /')
            [ -z "${image}" ] && terminate "Service '${service}' not found"
            name=$(echo "${image}" | awk -F'"' '{print $2}')
            images="${images} ${name}"
            echo "${image}"
        done
    else
        # Confirm only one service is defined in terminal mode
        targets=$(echo "${yaml}" | grep "_image=" | sed 's/^services_/  /')
        count=$(echo "${targets}" | wc -l)
        [ "${count}" -gt 1 ] && [ "${terminal}" = 'true' ] && terminate "Terminal mode supports one service only"
        name=$(echo "${targets}" | awk -F'"' '{print $2}')
        images="${images} ${name}"
        echo "${targets}"
    fi

    # clean up temporary files
    if [ -n "${temp_file}" ]; then
        rm -f "${temp_file}" || true
    fi

    echo
}

#=======================================================================================================================
# Display script version information.
#=======================================================================================================================
# Globals:
#   - script_version
# Outputs:
#   Writes version information to stdout.
#=======================================================================================================================
execute_show_version() {
    script=$(basename "$0")
    log "${script} version ${script_version}"
}


#=======================================================================================================================
# Main Script
#=======================================================================================================================

#=======================================================================================================================
# Entrypoint for the script.
#=======================================================================================================================
main() {
    # initialize global settings
    init_config

    # validate Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        terminate "Docker daemon not running"
    fi

    # Initialize build version and change to working directory
    BUILD_VERSION=$(cat 'VERSION' 2> /dev/null)
    export BUILD_VERSION
    cd "${docker_working_dir}" 2> /dev/null || terminate "Cannot find working directory: ${docker_working_dir}"

    # Parse arguments and initialize environment variables
    parse_args "$@"
    [ "${command}" = 'version' ] && execute_show_version && exit
    [ "${command}" = 'dev' ] && export IMAGE_SUFFIX='-debug' 
    if [ "${command}" = 'check' ]; then
        execute_check_upgrades && exit || exit 1
    fi
    staged=$(export_env_values)
    eval "${staged}"

    # Display environment and targeted images
    execute_validate_and_show_env
    print_status "Exporting environment variables"
    echo "${staged}" | sed 's/^export /  /g'
    echo
    execute_validate_and_show_images

    # Execute workflows
    case "${subcommand}" in
        build)   execute_build;;
        config)  execute_config;;
        deploy)  execute_deploy;;
        down)    execute_down;;
        stop)    execute_stop;;
        up)      execute_run;;
        *)       terminate "Invalid subcommand"
    esac

    echo "Done."
}

main "$@"