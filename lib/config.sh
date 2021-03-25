#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly DBM_CONFIG_FILE='dbm.ini'
readonly DBM_DIGEST_FILE='dbm.digest'
readonly DBM_VERSION_FILE='VERSION'


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
config_digest_file=''
config_version_file="${DBM_VERSION_FILE}"

#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Cleans the current digest file by removing all url/tag combination that no longer exist as dependency in the
# configuration file. Read/write access to the temp folder is required.
#=======================================================================================================================
# Arguments:
#   $1 - Normalized dependencies, e.g. '9:ALPINE hub.docker.com _ alpine 3.13.2-rc;'
# Outputs:
#   Cleaned digest file, or non-zero return code in case of errors.
#=======================================================================================================================
clean_digest_file() {
    dependencies="$1"
    [ -z "${dependencies}" ] && return 1
    { [ -z "${config_digest_file}" ] || [ ! -f "${config_digest_file}" ]; } && return 1

    # read the dependencies and move the digest file to a temp location
    # note: an extra empty line is appended at the end to ensure the read loop captures all lines
    temp_digest_file=$(mktemp -t "dbm_temp_digest.XXXXXXXXX")
    mv "${config_digest_file}" "${temp_digest_file}" && echo >> "${temp_digest_file}" || return 1

    # recreate digest file for all current digests with a matching dependency
    while read -r line; do
        url=$(echo "${line}" | awk -F' ' '{print $1}') # read stored url
        version=$(echo "${line}" | awk -F' ' '{print $2}') # read stored version
        if has_dependency_version "${url}" "${version}" "${dependencies}"; then
            echo "${line}" >> "${config_digest_file}"
        fi
    done < "${temp_digest_file}"

    rm "${temp_digest_file}" || true
    return 0
}

# shellcheck disable=SC2059
#=======================================================================================================================
# Finds and exports the local digest for each dependency defined in the default config file. The local digest is
# retrieved from the file 'dbm.digest' in the same folder as the 'dbm.ini' file. The export is skipped if no digest is
# found, however, the function then returns the exit value 1. 
# For example, the entry 'DBM_ALPINE_VERSION=hub.docker.com/_/alpine 3.13.2' in the file 'dbm.ini' is returned as
# 'export ALPINE_DIGEST=sha256:a75afd8b57e7f34e4dad8d65e2c7ba2e1975c795ce1ee22fa34f8cf46f96a3be'.
#=======================================================================================================================
# Outputs:
#   Writes image digests to stdout.
#=======================================================================================================================
export_digest_values() {
    dependencies=$(read_dependencies)
    results=''
    flag=0

    { [ -z "${dependencies}" ] || [ "${dependencies}" = ';' ]; } && return 0

    IFS=';' # initialize dependency separator
    for item in $dependencies; do
        # validate if the item has the expected number of tokens
        is_valid_dependency "${item}" || { flag=1; continue; }

        # retrieve key fields
        {
            name=$(get_dependency_name "${item}") && \
            provider=$(get_dependency_provider "${item}") && \
            owner=$(get_dependency_owner "${item}") && \
            repo=$(get_dependency_repository "${item}") && \
            version=$(get_dependency_version "${item}") && \
            extension=$(get_dependency_extension "${item}")
        } || { flag=1; continue; }

        # read local digest
        local_digest=$(read_stored_digest "${provider}/${owner}/${repo}" "v${version}${extension}") || \
            { flag=1; continue; }
        results="${results}export ${name}_DIGEST=${local_digest}\n"
    done

    printf "${results}"
    return "${flag}"
}

#=======================================================================================================================
# Exports all key/value pairs beginning with 'DBM_*' from the default config file. The output is written to stdout with
# the prefix 'export ' for each line. For example, the entry 'DBM_ALPINE_VERSION=hub.docker.com/_/alpine 3.13.2' in the
# file 'dbm.ini' is returned as 'export ALPINE_VERSION=3.13.2'.
#=======================================================================================================================
# Outputs:
#   Writes matching key/value pairs to stdout.
#=======================================================================================================================
# shellcheck disable=SC2059
export_env_values() {
    [ ! -f "${config_file}" ] && err "Cannot find config file: ${config_file}" && return 1
    
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
            err "Invalid entry in '${config_file}': ${item}"
            return 1
        fi
    done

    printf "${results}"
    return 0
}

#=======================================================================================================================
# Reads the name of a dependency normalized by read_dependencies(). The name is the first item on the provided line
# input. As an example, the input line '9:ALPINE hub.docker.com _ alpine 3.13.2' returns the name 'ALPINE'.
#=======================================================================================================================
# Arguments:
#   $1 - Normalized dependency item, e.g. '9:ALPINE hub.docker.com _ alpine 3.13.2'
# Outputs:
#   Writes name to stdout, returns 1 on error.
#=======================================================================================================================
get_dependency_name() {
    item="$1"
    name=$(echo "${item}" | awk -F' ' '{print $1}' | awk -F':' '{print $2}')
    [ -z "${name}" ] && err "Cannot read dependency name" && return 1
    echo "${name}" && return 0
}

#=======================================================================================================================
# Reads the provider of a dependency normalized by read_dependencies(). The provider is the second item on the provided
# line input. As an example, the input line '9:ALPINE hub.docker.com _ alpine 3.13.2' returns the provider 
# 'hub.docker.com'. The provider identification is altered to lower case.
#=======================================================================================================================
# Arguments:
#   $1 - Normalized dependency item, e.g. '9:ALPINE hub.docker.com _ alpine 3.13.2-rc'
# Outputs:
#   Writes provider to stdout, returns 1 on error.
#=======================================================================================================================
get_dependency_provider() {
    item="$1"
    provider=$(echo "${item}" | awk -F' ' '{print $2}' | tr '[:upper:]' '[:lower:]') # make case insensitive
    [ -z "${provider}" ] && err "Cannot read dependency provider" && return 1
    echo "${provider}" && return 0
}

#=======================================================================================================================
# Reads the owner of a dependency normalized by read_dependencies(). The owner is the third item on the provided
# line input. As an example, the input line '9:ALPINE hub.docker.com _ alpine 3.13.2' returns the owner '_'.
#=======================================================================================================================
# Arguments:
#   $1 - Normalized dependency item, e.g. '9:ALPINE hub.docker.com _ alpine 3.13.2-rc'
# Outputs:
#   Writes owner to stdout, returns 1 on error.
#=======================================================================================================================
get_dependency_owner() {
    item="$1"
    owner=$(echo "${item}" | awk -F' ' '{print $3}')
    [ -z "${owner}" ] && err "Cannot read dependency owner" && return 1
    echo "${owner}" && return 0
}

#=======================================================================================================================
# Reads the repository name of a dependency normalized by read_dependencies(). The repository is the fourth item on the
# provided line input. As an example, the input line '9:ALPINE hub.docker.com _ alpine 3.13.2' returns the repository
# 'alpine'.
#=======================================================================================================================
# Arguments:
#   $1 - Normalized dependency item, e.g. '9:ALPINE hub.docker.com _ alpine 3.13.2-rc'
# Outputs:
#   Writes repository to stdout, returns 1 on error.
#=======================================================================================================================
get_dependency_repository() {
    item="$1"
    repository=$(echo "${item}" | awk -F' ' '{print $4}')
    [ -z "${repository}" ] && err "Cannot read dependency repository" && return 1
    echo "${repository}" && return 0
}

#=======================================================================================================================
# Reads the tag of a dependency normalized by read_dependencies(). The tag is the fith item on the provided line input.
# As an example, the input line '9:ALPINE hub.docker.com _ alpine 3.13.2' returns the tag '3.13.2'.
#=======================================================================================================================
# Arguments:
#   $1 - Normalized dependency item, e.g. '9:ALPINE hub.docker.com _ alpine 3.13.2-rc'
# Outputs:
#   Writes tag to stdout, returns 1 on error.
#=======================================================================================================================
get_dependency_tag() {
    item="$1"
    tag=$(echo "${item}" | awk -F' ' '{print $5}')
    [ -z "${tag}" ] && err "Cannot read dependency tag" && return 1
    echo "${tag}" && return 0
}

#=======================================================================================================================
# Reads the semantic version of a dependency normalized by read_dependencies(). The version is the fith item on the
# provided line input. For the version to be correctly identified, at least 'MAJOR.MINOR' is required, 'v' and PATCH are
# optional. Any remaining characters are returned by get_dependency_extension() instead. As an example, the input line 
# '9:ALPINE hub.docker.com _ alpine 3.13.2-rc' returns the version '3.13.2'. 
#=======================================================================================================================
# Arguments:
#   $1 - Normalized dependency item, e.g. '9:ALPINE hub.docker.com _ alpine 3.13.2-rc'
# Outputs:
#   Writes version to stdout, returns 1 on error.
#=======================================================================================================================
get_dependency_version() {
    item="$1"

    count=$(echo "${item}" | wc -w) # identify number of parsed arguments (should be 2 or 5)
    if [ "${count}" -eq 2 ]; then
        get_dependency_provider "${item}" || { err "Cannot read dependency version"; return 1; }
        return 0
    fi

    tag=$(echo "${item}" | awk -F' ' '{print $5}')
    version=$(echo "${tag}" | grep -Eo "^${VERSION_REGEX}")
    version=$(echo "${version}" | sed 's/^v//g;s/^V//g;') # strip 'v' or 'V' prefix
    version=$(_expand_version "${version}") # expand version info if needed with minor and patch

    [ -z "${version}" ] && err "Cannot read dependency version" && return 1
    echo "${version}" && return 0
}

#=======================================================================================================================
# Reads the version extension of a dependency normalized by read_dependencies(). The version extension is the fith item
# on the provided line input. The extension is the remainder of a tag, stripped from its semantic version by 
# get_dependency_version(). As an example, the input line '9:ALPINE hub.docker.com _ alpine 3.13.2-rc' returns the
# extension '-rc'. 
#=======================================================================================================================
# Arguments:
#   $1 - Normalized dependency item, e.g. '9:ALPINE hub.docker.com _ alpine 3.13.2-rc'
# Outputs:
#   Writes version to stdout, returns 1 on error.
#=======================================================================================================================
get_dependency_extension() {
    item="$1"

    count=$(echo "${item}" | wc -w) # identify number of parsed arguments (should be 2 or 5)
    [ "${count}" -eq 2 ] && echo '' && return 0

    extension=$(echo "${item}" | awk -F' ' '{print $5}')
    version=$(echo "${extension}" | grep -Eo "^${VERSION_REGEX}")
    esc_version=$(escape_string "${version}")

    [ -n "${esc_version}" ] && extension=$(echo "${extension}" | sed "s/${esc_version}//g") # strip version information
    echo "${extension}" && return 0
}

#=======================================================================================================================
# Validates if a given url/tag combination exists as dependency (normalized by read_dependencies()). 
#=======================================================================================================================
# Arguments:
#   $1 - Url, e.g. 'hub.docker.com/_/alpine'
#   $2 - Tag, e.g. '3.13.2-rc'
#   $3 - Normalized dependencies, e.g. '9:ALPINE hub.docker.com _ alpine 3.13.2-rc;'
# Outputs:
#   Returns 0 if found, 1 otherwise
#=======================================================================================================================
has_dependency_version() {
    input_url="$1"
    input_tag="$2"
    dependencies="$3"
    match=1

    { [ -z "${dependencies}" ] || [ -z "${input_url}" ] || [ -z "${input_tag}" ]; } && return 1

    # scan each dependency for a potential match
    IFS=';' # initialize dependency separator
    for item in $dependencies; do
        # confirm if valid dependency (number of arguments should be 5)
        count=$(echo "${item}" | wc -w)
        [ "${count}" -ne 5 ] && continue

        # retrieve normalized dependencies from config file
        provider=$(get_dependency_provider "${item}") || continue
        owner=$(get_dependency_owner "${item}") || continue
        repo=$(get_dependency_repository "${item}") || continue
        version=$(get_dependency_version "${item}") || continue
        extension=$(get_dependency_extension "${item}") || continue

        # compare url and tag with normalized dependency
        url="${provider}/${owner}/${repo}"
        tag="v${version}${extension}"
        [ "${input_url}" = "${url}" ] && [ "${input_tag}" = "${tag}" ] && match=0 && break
    done

    return "${match}"
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
    # read entry from config file
    if match=$(grep -in "^$1=" "${config_file}" 2> /dev/null); then
        line=$(echo "${match}" | awk -F':' '{print $1}') # read line number
        value=$(echo "${match}" | awk -F'=' '{print $2}') # read setting value
    else
        value="$2" # assign a default value if needed
    fi

    # remove / validate quotes
    left=$(echo "${value}" | cut -c1)
    right=$(echo "${value}" | rev | cut -c1)
    if [ "${left}" = "${right}" ]; then
        quote="${left}"
        value="${value%${quote}}"
        value="${value#${quote}}"
    elif [ "${left}" = "'" ] || [ "${left}" = "\"" ] || [ "${right}" = "'" ] || [ "${right}" = "\"" ]; then
        { [ -n "${line}" ] && err "Invalid character found in config file line ${line}: ${value}"; } || \
            err "Invalid character found in default value for variable '$1': $2"
        return 1
    fi

    # write value to stdout
    printf "%s" "${value}"
    return 0
}

#=======================================================================================================================
# Conducts a shallow validation of a dependency normalized by read_dependencies(). The number of tokens (words seperated
# by a space character) should be either 2 or 5. If the input starts with a valid line number, the original input from
# the configuration file is added to the error message if applicable. The following inputs are all valid examples:
#   'ALPINE hub.docker.com _ alpine 3.13.2-rc' - returns 0
#   'ALPINE 3.13.2-rc' - returns 2
#   '9:ALPINE hub.docker.com _ alpine 3.13.2-rc' - returns 0
#   '9:ALPINE 3.13.2-rc' - returns 2
#=======================================================================================================================
# Arguments:
#   $1 - Normalized dependency item, e.g. '9:ALPINE hub.docker.com _ alpine 3.13.2-rc'
# Outputs:
#   Returns one of the following codes, with an error message printed to stdout if applicable:
#    0 - Input is valid
#    1 - Input is empty
#    2 - Dependency has no provider url
#    3 - Dependency is malformed (expected 5 arguments)
#=======================================================================================================================
is_valid_dependency() {
    input="$1"    
    [ -z "${input}" ] && return 1
    filename=$(basename "$1")

    # validate number of arguments
    count=$(echo "${item}" | wc -w) # identify number of parsed arguments (should be 2 or 5)
    line_no=$(echo "${item}" | awk -F':' '{print $1}')
    input=''
    status=''
    [ "${count}" -eq 2 ] && status='no_link'
    [ "${count}" -ne 5 ] && status='malformed'

    # get the original input, fallback to parsed input if needed
    if [ -n "${status}" ]; then
        if is_number "${line_no}"; then
            input=$(eval "awk 'NR==${line_no}' ${config_file}" 2> /dev/null)
            length=$(echo "${input}" | awk '{print length}')
            [ "${length}" -gt 80 ] && input=$(echo "${input}" | cut -c1-77) && input="${input}..."
        fi
        [ -z "${input}" ] && input="${item}"
    fi

    # return an informative message in case of errors
    case "${status}" in
        no_link) 
            if [ -n "${line_no}" ]; then
                echo "Line ${line_no} of '${filename}' has no repository link, skipping item: ${input}"
            else 
                echo "Dependency has no repository link, skipping item: ${item}"
            fi
            return 2
        ;;
        malformed)
            if [ -n "${line_no}" ]; then
                echo "Line ${line_no} of '${filename}' is malformed, skipping item: ${input}"
            else 
                echo "Dependency is malformed, skipping item: ${item}"
            fi
            return 3
    esac

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
#   $1 - Base directory of the config file.
# Outputs:
#   Initalized global config variables, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
init_config() {
    basedir="${1:-$PWD}"
    config_file_override="${2:-${DBM_CONFIG_FILE}}"
    
    # continue if file(s) do not exist
    config_file=$(get_absolute_path "${basedir}" "${config_file_override}")
    if [ -n "${config_file}" ]; then
        dir=$(dirname "${config_file}")
        config_digest_file=$(echo "${dir}/${DBM_DIGEST_FILE}" | sed 's|//|/|g')
        config_version_file=$(echo "${dir}/${DBM_VERSION_FILE}" | sed 's|//|/|g')
    fi
    
    # initialize settings and/or default values 
    config_docker_working_dir=$(init_config_value 'DOCKER_WORKING_DIR' 'docker') || \
        { err "Cannot read config value DOCKER_WORKING_DIR"; return 1; }
    config_docker_base_yml=$(init_config_value 'DOCKER_BASE_YML' 'docker-compose.yml') || \
        { err "Cannot read config value DOCKER_BASE_YML"; return 1; }
    config_docker_prod_yml=$(init_config_value 'DOCKER_PROD_YML' 'docker-compose.prod.yml') || \
        { err "Cannot read config value DOCKER_PROD_YML"; return 1; }
    config_docker_dev_yml=$(init_config_value 'DOCKER_DEV_YML' 'docker-compose.dev.yml') || \
        { err "Cannot read config value DOCKER_DEV_YML"; return 1; }
    config_docker_service=$(init_config_value 'DOCKER_SERVICE_NAME' "${PWD##*/}") || \
        { err "Cannot read config value DOCKER_SERVICE_NAME"; return 1; }
    # TODO: fix on Ubuntu
    config_docker_platforms=$(init_config_value 'DOCKER_TARGET_PLATFORM' '') || \
        { err "Cannot read config value DOCKER_TARGET_PLATFORM"; return 1; }

    return 0
}

#=======================================================================================================================
# Reads all dependencies defined within the configuration file, identified by the pattern '^DBM_.*VERSION=.*'. Comments,
# trailing spaces, and protocols (http/https) are stripped. The function returns a single line of all identified
# dependencies as key-value pairs, separated by ';'. Each item is prefixed with the corresponding line number.
#=======================================================================================================================
# Outputs:
#   Initalized global config variables, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
read_dependencies() {
    [ ! -f "${config_file}" ] && return 1

    # retrieve all dependendencies from the DBM config file with their line number
    # remove all comments, trailing spaces, and protocols; separate each dependency by a ';'
    dependencies=$(grep -n '^DBM_.*VERSION=.*' "${config_file}" | sed -r 's/(^[0-9]*:)DBM_/\1/g;')
    dependencies=$(echo "${dependencies}" | sed 's/hub.docker.com\/r\//hub.docker.com\//g')
    dependencies=$(echo "${dependencies}" | sed 's/_VERSION=/ /g;s/\// /g;')
    dependencies=$(echo "${dependencies}" | sed -e 's/\s*#.*$//;s/[[:space:]]*$//;')
    dependencies=$(echo "${dependencies}" | sed -e 's/http:  //g;s/https:  //g;')
    printf "%s\n\n" "${dependencies}" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/;/g'
    return 0
}

#=======================================================================================================================
# Reads the digest associated with a repository link and version from a local digest file. If no digest is found, the
# default value is used instead. In this case, the local digest file is updated too.
#=======================================================================================================================
# Arguments:
#   $1 - Normalized source repository link, e.g. 'hub.docker.com/_/alpine'
#   $2 - Fully expanded dependency version, e.g. 'v3.13.2'
# Outputs:
#   Writes setting to stdout.
#=======================================================================================================================
read_stored_digest() {
    url="$1"
    version="$2"

    { [ -z "${url}" ] || [ -z "${version}" ]; } &&  { err "Missing url and version"; return 1; }

    # read the digest from the local digest file
    match=$(grep -in "^${url} ${version}" "${config_digest_file}" 2> /dev/null) # read entry from digest file
    digest=$(echo "${match}" | awk -F' ' '{print $3}' | sed 's/[\n\r]//g') # read stored digest

    # write value to stdout
    [ -z "${digest}" ] && return 1
    printf '%s' "${digest}"
    return 0
}

#=======================================================================================================================
# Reads the digest associated with a repository link and version from a local digest file. If no digest is found, the
# default value is used instead. In this case, the local digest file is updated too.
#=======================================================================================================================
# Arguments:
#   $1 - Normalized source repository link, e.g. 'hub.docker.com/_/alpine'
#   $2 - Fully expanded dependency version, e.g. 'v3.13.2'
#   $3 - Default digest value, e.g. 'sha256:a75afd8b57e7f34e4dad8d65e2c7ba2e1975c795ce1ee22fa34f8cf46f96a3be'
# Outputs:
#   Writes setting to stdout and updates local digest file.
#=======================================================================================================================
read_update_stored_digest() {
    url="$1"
    version="$2"
    digest="$3"

    { [ -z "${url}" ] || [ -z "${version}" ]; } &&  { err "Missing url and version"; return 1; }

    # read the digest from the local digest file
    match=$(grep -in "^${url} ${version}" "${config_digest_file}" 2> /dev/null) # read entry from digest file
    value=$(echo "${match}" | awk -F' ' '{print $3}' | sed 's/[\n\r]//g') # read stored digest

    # update digest and digest file if needed
    if [ -z "${value}" ] && [ -n "${digest}" ]; then
        value="${digest}"
        echo "${url} ${version} ${digest}" >> "${config_digest_file}"
        test -w "${config_digest_file}" || { err "Digest file not writable: ${config_digest_file}"; return 1; }
    fi

    # write value to stdout
    printf '%s' "${value}"
    return 0
}