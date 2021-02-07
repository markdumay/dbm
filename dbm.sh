#!/bin/sh

#=======================================================================================================================
# Title         : dbm.sh
# Description   : Helper script to manage Docker images
# Author        : Mark Dumay
# Date          : February 7th, 2021
# Version       : 0.3.0
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
readonly DOCKER_EXEC='docker exec -it'


#=======================================================================================================================
# Variables
#=======================================================================================================================
detached='false'
terminal='false'
command=''
services=''
subcommand=''
docker_base=''
docker_prod=''
docker_dev=''
docker_stack=''
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
    echo "  prod                   Target a production image"
    echo "  dev                    Target a development image"
    echo "  version                Show version information"
    echo
    echo "Subcommands (prod and dev):"
    echo "  build                  Build a Docker image"
    echo "  deploy                 Deploy the container as Docker Stack service"
    echo "  down                   Stop a running container and remove defined containers/networks"
    echo "  up                     Run a Docker image as container"
    echo "  stop                   Stop a running container"
    echo
    # TODO: decide wether to support optional .env file
    # echo "Options:"
    # echo "  -e, --env FILE         Use FILE for environment variables, defaults to 'build.env'"
    # echo
    echo "Options (up only):"
    echo "  -d, --detached         Run in detached mode"
    echo "  -t, --terminal         Run in detached mode and start terminal (if supported by image)"
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

#=======================================================================================================================
# Validates if a variable is a valid positive integer.
#=======================================================================================================================
# Arguments:
#   $1 - Variable to test.
# Outputs:
#   Return 0 if valid and returns 1 if not valid.
#=======================================================================================================================
is_number() {
    [ -n "$1" ] && [ -z "${1##[0-9]*}" ] && return 0 || return 1
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
#   Writes warning or error to stdout if applicable, terminates with non-zero exit code on fatal error
#=======================================================================================================================
parse_args() {
    subcommand=''

    # Process and validate command-line arguments
    while [ -n "$1" ]; do
        case "$1" in
            -d | --detached )                  detached='true';;
            -t | --terminal )                  terminal='true';;
            dev | prod)                        command="$1";;
            version)                           command="$1";;
            build | deploy | down | stop | up) subcommand="$1";;
            * )                                services="${services} $1"
        esac
        shift
    done

    # Validate arguments
    fatal_error=''
    warning=''
    prefix=$(echo "${services}" | cut -c1)
    service_count=$(echo "${services}" | wc -w)
    # Requirement 1 - A single value command is provided
    if [ -z "${command}" ]; then fatal_error="Expected command"
    # Requirement 2 - No subcommand, flags, or services is defined for the command 'version'
    elif [ "${command}" = 'version' ] && 
         [ -n "${subcommand}" ] && \
         [ -n "${services}" ] && \
         [ "${detached}" != 'false' ] && \
         [ "${terminal}" != 'false' ]; then fatal_error="Invalid arguments"
    # Requirement 3 - A subcommand is provided for all commands except 'version'
    elif [ "${command}" != 'version' ] && [ -z "${subcommand}" ]; then fatal_error="Expected subcommand"
    # Requirement 4 - At most one service is defined in terminal mode
    elif [ "${terminal}" = 'true' ] && \
         [ "${service_count}" -gt 1 ]; then 
         fatal_error="Terminal mode supports one service only"
    # Warning 1 - Detached mode is not specified in terminal mode
    elif [ "${detached}" = 'true' ] && \
         [ "${terminal}" = 'true' ]; then
        warning="Ignoring detached mode argument"
    # Requirement 6 - Services do not start with '-' character
    elif [ "${prefix}" = "-" ]; then fatal_error="Invalid option"
    fi
    
    # Inform user and terminate on fatal error
    [ -n "${fatal_error}" ] && usage && terminate "${fatal_error}"
    [ -n "${warning}" ] && log "WARN: ${warning}"

    # Standardize arguments
    [ "${terminal}" = 'true' ] && detached='true'
    services=$(echo "${services}" | awk '{gsub(/^ +| +$/,"")} {print $0}') # remove spaces
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

    # set the Docker command arguments
    docker_base="-f ${docker_base_yml}"
    docker_prod="${docker_base} -f ${docker_prod_yml}"
    docker_dev="${docker_base} -f ${docker_dev_yml}"
    docker_stack="docker stack deploy -c - ${docker_service}"

    # init script version info
    script_dir=$(dirname "$0")
    script_version=$(cat "${script_dir}/VERSION" 2> /dev/null)
    script_version="${script_version:-unknown}"
}

#=======================================================================================================================
# Workflow Functions
#=======================================================================================================================

#=======================================================================================================================
# Build a Docker image.
#=======================================================================================================================
# Outputs:
#   New Docker image.
#=======================================================================================================================
execute_build() {
    print_status "Building images"
    [ "${command}" = 'dev' ] && base_cmd="${DOCKER_RUN} ${docker_dev} build" || 
        base_cmd="${DOCKER_RUN} ${docker_prod} build"
    t1=$(date +%s)
    eval "${base_cmd} ${services}"
    t2=$(date +%s)
    elapsed_string=$(display_time $((t2 - t1)))
    [ "${t2}" -gt "${t1}" ] && log "Total build time ${elapsed_string}"
}

#=======================================================================================================================
# Deploy a Docker image as Docker Stack service(s).
#=======================================================================================================================
# Outputs:
#   New Docker Stack service(s).
#=======================================================================================================================
execute_deploy() {
    print_status "Deploying Docker Stack services"
    [ "${command}" = 'dev' ] && base_cmd="${DOCKER_RUN} ${docker_dev}" || 
        base_cmd="${DOCKER_RUN} ${docker_prod}"
    eval "${base_cmd} config | ${docker_stack}"
}

#=======================================================================================================================
# Stop a running container and remove defined containers/networks.
#=======================================================================================================================
# Outputs:
#   New Docker image.
#=======================================================================================================================
execute_down() {
    print_status "Bringing containers and networks down"
    [ "${command}" = 'dev' ] && base_cmd="${DOCKER_RUN} ${docker_dev} down" || 
        base_cmd="${DOCKER_RUN} ${docker_prod} down"
    eval "${base_cmd} ${services}"
}

#=======================================================================================================================
# Run a Docker image as container.
#=======================================================================================================================
# Outputs:
#   New Docker image.
#=======================================================================================================================
execute_run() {
    print_status "Bringing containers and networks up"

    # define base command and flags
    [ "${command}" = 'dev' ] && base_cmd="${DOCKER_RUN} ${docker_dev}" || base_cmd="${DOCKER_RUN} ${docker_prod}"
    [ "${detached}" = 'true' ] && flags=' -d' || flags='' 

    # bring container up
    eval "${base_cmd} up ${flags} --remove-orphans ${services}"

    # start terminal if applicable
    if [ "${terminal}" = 'true' ] ; then
        # get container ID
        id=$(eval "${DOCKER_RUN} ps -q ${services}")
        # shellcheck disable=SC2181
        [ "$?" != 0 ] && terminate "Container ID not found"        
        count=$(echo "${id}" | wc -l)
        [ "${count}" -gt 1 ] && terminate "Terminal supports one container only"
        eval "${DOCKER_EXEC} ${id} sh" # start sh terminal
    fi

    # bring container down when done and not detached or if in terminal mode
    { [ "${detached}" = 'false' ] || [ "${terminal}" = 'true' ]; } && eval "${base_cmd} down"
}

#=======================================================================================================================
# Stop a running container.
#=======================================================================================================================
# Outputs:
#   New Docker image.
#=======================================================================================================================
execute_stop() {
    print_status "Stopping containers and networks"
    [ "${command}" = 'dev' ] && base_cmd="${DOCKER_RUN} ${docker_dev} stop" || 
        base_cmd="${DOCKER_RUN} ${docker_prod} stop"
    eval "${base_cmd} ${services}"
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
    log "  Docker Engine:  v${docker_version}"
    log "  Docker Compose: v${compose_version}"
    log "  Host:           ${os}/${arch}"
    echo
}

#=======================================================================================================================
# Validate Docker compose configuration. Show image information on console.
#=======================================================================================================================
# Outputs:
#   Writes targeted image information to stdout, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
execute_validate_and_show_images() {
    print_status "Identifying targeted images"

    # Generate temp Docker compose configuration using variable substitution
    [ "${command}" = 'dev' ] && base_cmd="${DOCKER_RUN} ${docker_dev} config" || 
        base_cmd="${DOCKER_RUN} ${docker_prod} config"
    temp_file=$(mktemp -t "${docker_service}.XXXXXXXXX")
    eval "${base_cmd} > ${temp_file}"
    yaml=$(parse_yaml "${temp_file}")
    # shellcheck disable=SC2181
    [ "$?" -ne 0 ] && terminate "Cannot generate Docker compose configuration"
    
    # Show targeted images information, filtered for services if applicable
    if [ -n "${services}" ] ; then
        for service in $services; do
            image=$(echo "${yaml}" | grep "^services_${service}_image=" | sed 's/^services_/  /' | sed 's/=/: /')
            [ -z "${image}" ] && terminate "Service '${service}' not found"
            echo "${image}"
        done
    else
        # Confirm only one service is defined in terminal mode
        images=$(echo "${yaml}" | grep "_image=" | sed 's/^services_/  /')
        count=$(echo "${images}" | wc -l)
        [ "${count}" -gt 1 ] && [ "${terminal}" = 'true' ] && terminate "Terminal mode supports one service only"
        echo "${images}"
    fi
    rm -f "${temp_file}" || true
    echo
}

#=======================================================================================================================
# Display script version information
#=======================================================================================================================
# Globals:
#   - script_version
# Outputs:
#   Writes version information to stdout.
#=======================================================================================================================
execute_show_version() {
    # TODO: suppress warnings
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

    # Initialize build version and change to working directory
    BUILD_VERSION=$(cat 'VERSION' 2> /dev/null)
    export BUILD_VERSION

    # Parse arguments and initialize environment variables
    parse_args "$@"
    [ "${command}" = 'version' ] && execute_show_version && exit
    [ "${command}" = 'dev' ] && export IMAGE_SUFFIX='-debug' 

    # Display environment and targeted images
    cd "${docker_working_dir}" 2> /dev/null || terminate "Cannot find working directory: ${docker_working_dir}"
    execute_validate_and_show_env
    execute_validate_and_show_images

    # Execute workflows
    case "${subcommand}" in
        build)   execute_build;;
        deploy)  execute_deploy;;
        down)    execute_down;;
        stop)    execute_stop;;
        up)      execute_run;;
        *)       terminate "Invalid subcommand"
    esac

    echo "Done."
}

main "$@"