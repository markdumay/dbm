#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly DOCKER_API='https://hub.docker.com/v2'
readonly DOCKER_AUTH='https://auth.docker.io'
readonly DOCKER_REGISTRY_DOMAIN='https://registry-1.docker.io'
readonly DOCKER_MANIFEST_HEADER='application/vnd.docker.distribution.manifest.list.v2+json'
readonly DOCKER_API_PAGE_SIZE=100 # Limit Docker API results to the first 100 only
readonly GITHUB_API='https://api.github.com'
readonly GITHUB_HEADER='application/vnd.github.v3+json'
readonly VERSION_REGEX='([vV])?[0-9]+\.[0-9]+(\.[0-9]+)?' #  MAJOR.MINOR required, 'v' and PATCH are optional

#=======================================================================================================================
# Internal Functions
#=======================================================================================================================

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
_expand_version() {
    if echo "$1" | grep -qEo "^[0-9]+$"; then
        echo "$1.0.0$2"
    elif echo "$1" | grep -qEo "^[0-9]+.[0-9]+$"; then
        echo "$1.0$2"
    else
        echo "$1$2"
    fi
}

#======================================================================================================================
# Retrieves the SHA digest for a specific tagged image from the Docker Hub. For regular images, the image digest is 
# retrieved. For multi-architecture images, the repository digest is obtained instead. The output should be compatible
# with the digest information retrieved by 'docker pull'. The returned digest includes the encoding prefix, typically
# 'sha256'.
#
# Regular image example:
#   _get_docker_digest 'library' 'varnish' '6.5.1-1'
#   sha256:9f1c24b270e55593b90fe1df8d9d6c362b2245920d4b333f78884c750132a2bb
#   Compare the result with the digest retrieved by 'docker pull varnish:6.5.1-1'
#
# Multi-architecture image example:
#   _get_docker_digest 'library' 'ghost' '4.0.1-alpine'
#   sha256:7f3710185d1b70ededdd2994a57df504897b8e9fca2a7c992553cb2ae4f5a21c
#   Compare the result with the digest retrieved by 'docker pull ghost:4.0.1-alpine'
#======================================================================================================================
# Arguments:
#   $1 - Repository owner.
#   $2 - Repository name.
#   $3 - Image tag.
# Outputs:
#   SHA256 digest of the remote image or repository.
#======================================================================================================================
_get_docker_digest() {
    [ "$1" = "_" ] && owner='library' || owner=$(url_encode "$1") # Update owner of official Docker repositories    
    repository=$(url_encode "$2")
    tag=$(url_encode "$3")
    digest=''

    # Retrieve authorization token for targeted repository
    token=$(curl -sSL "${DOCKER_AUTH}/token?service=registry.docker.io&scope=repository:${owner}/${repository}:pull" \
            | jq --raw-output .token 2> /dev/null)
    [ -z "${token}" ] && echo "Cannot retrieve authorization token" && return 1

    # Request a "fat manifest" by default, HEAD only
    response=$(curl --HEAD -sH "Authorization: Bearer ${token}" \
        -H "Accept: ${DOCKER_MANIFEST_HEADER}" "${DOCKER_REGISTRY_DOMAIN}/v2/${owner}/${repository}/manifests/${tag}")
    [ -z "${response}" ] && echo "Cannot retrieve manifest data" && return 1
    response=$(echo "${response}" | tr -d '\r') # remove special character '\r'

    if echo "${response}" | grep -q "${DOCKER_MANIFEST_HEADER}"; then
        # Capture the repository digest for a multi-architecture image
        digest=$(echo "${response}" | grep 'Docker-Content-Digest' | awk -F': ' '{print $2}')
    else
        # Capture the repository digest for a regular image
        digest=$(curl -s "${DOCKER_API}/repositories/${owner}/${repository}/tags/${tag}" | jq -r '.images[0].digest' 2> /dev/null )
    fi

    # Return the retrieved digest
    [ -z "${digest}" ] && echo "Cannot retrieve digest" && return 1 
    echo "${digest}"
    return 0
}

#======================================================================================================================
# Retrieves the SHA digest for a specific tagged release from GitHub. The version prefix 'v' is optional. The returned
# digest includes the encoding prefix 'sha'.
#======================================================================================================================
# Arguments:
#   $1 - Repository owner.
#   $2 - Repository name.
#   $3 - Release tag.
#   $4 - Shortens the SHA digest when 'true', defaults to 'false'.
# Outputs:
#   SHA digest of the tagged GitHub release.
#======================================================================================================================
# TODO: use token
_get_github_digest() {
    owner=$(url_encode "$1")
    repository=$(url_encode "$2")
    tag=$(url_encode "$3")
    short="$4"

    # Get all tags
    tags=$(curl -sH "Accept: ${GITHUB_HEADER}" "${GITHUB_API}/repos/${owner}/${repository}/tags")
    [ -z "${tags}" ] && echo "Cannot retrieve tags" && return 1
    
    # Get the digest matching the tag (with optional 'v' prefix)
    digest=$(echo "${tags}" | jq -r ".[] | select(.name | test(\"^[vV]?${tag}\$\")) | .commit.sha" 2> /dev/null)

    # Validate the retrieved digest
    [ -z "${digest}" ] && echo "Cannot retrieve digest" && return 1 
    count=$(echo "${digest}" | wc -l)
    [ "${count}" -gt 1 ] && echo "Received multiple matches" && return 1

    # Return the retrieved digest
    [ "${short}" = 'true' ] && digest=$(echo "${digest}" | cut -c1-7)
    echo "sha:${digest}"
    return 0
}

#======================================================================================================================
# Retrieves the latest available tag from a GitHub repository. Release candidates are excluded by default. To avoid
# hitting the API rate limit, set the environment variable 'GITHUB_TOKEN' to a valid GitHub token with read access to
# repositories. This will increase the rate limit of 60 requests/hr to 5.000 requests/hr. Within GitHub actions, use
# the built-in GITHUB_TOKEN to increase the rate limit to 1.000 requests/hr per repository.
#======================================================================================================================
# Arguments:
#   $1 - Repository owner.
#   $2 - Repository name.
#   $3 - Optional release extension.
# Outputs:
#   Latest available tag if found, empty string otherwise.
#======================================================================================================================
_get_latest_github_tag() {
    owner=$(url_encode "$1")
    repo=$(url_encode "$2")
    extension=$(url_encode "$3")

    [ -n "${GITHUB_TOKEN}" ] && auth="--header 'authorization: Bearer ${GITHUB_TOKEN}'" || auth=''
    tag=$(eval "curl -s ${auth} ${GITHUB_API}/repos/${owner}/${repo}/releases/latest" | grep "tag_name" | awk -F'"' '{print $4}')
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
# TODO: use token
# TODO: see https://docs.docker.com/docker-hub/download-rate-limit/
# TODO: see https://cloud.google.com/container-registry/docs/pulling-cached-images
_get_latest_docker_tag() {
    [ "$1" = "_" ] && owner='library' || owner=$(url_encode "$1") # Update owner of official Docker repositories
    repo=$(url_encode "$2")
    extension=$(url_encode "$3")

    url="${DOCKER_API}/repositories/${owner}/${repo}/tags/?page_size=${DOCKER_API_PAGE_SIZE}"
    tags=$(curl -s "${url}")
    tags=$(echo "${tags}" | jq -r '.results|.[]|.name' 2> /dev/null | grep -E "^${VERSION_REGEX}${extension}$")
    echo "${tags}" | sort --version-sort | tail -n1
}


#=======================================================================================================================
# Functions
#=======================================================================================================================

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
# Arguments:
#   $2 - Normalized dependencies, e.g. '9:ALPINE hub.docker.com _ alpine 3.13.2-rc;'
# Outputs:
#   Writes matching key/value pairs to stdout. Returns 1 in case of potential updates, 0 otherwise.
#=======================================================================================================================
# shellcheck disable=SC2059
check_upgrades() {
    dependencies="$1"
    logs=''
    latest=''
    remote_digest=''
    flag=0

    { [ -z "${dependencies}" ] || [ "${dependencies}" = ';' ]; } && echo "No dependencies found" && return 0

    IFS=';' # initialize dependency separator
    width=0 # initialize tab width of first output column
    for item in $dependencies; do
        # validate if the item has the expected number of tokens
        if ! result=$(is_valid_dependency "${item}"); then
            [ "$?" -ne 2 ] && flag=1
            logs="${logs}${result}\n"
            continue
        fi

        # retrieve key fields
        {
            name=$(get_dependency_name "${item}") && \
            provider=$(get_dependency_provider "${item}") && \
            owner=$(get_dependency_owner "${item}") && \
            repo=$(get_dependency_repository "${item}") && \
            tag=$(get_dependency_tag "${item}") && \
            version=$(get_dependency_version "${item}") && \
            extension=$(get_dependency_extension "${item}")
        } || { logs="${logs}Skipping malformed dependency: ${item}\n"; flag=1; continue; }

        # set dependency display name and adjust column width if needed
        dependency="[${name} v${version}${extension}]"
        curr_width=$(echo "${dependency}" | awk '{print length}') # set current tab width
        [ "${curr_width}" -gt "${width}" ] && width="${curr_width}" # update tab width if needed
        
        # obtain latest tag and digest from supported providers
        case "${provider}" in
            hub.docker.com )
                latest=$(_get_latest_docker_tag "${owner}" "${repo}" "${extension}")
                remote_digest=$(_get_docker_digest "${owner}" "${repo}" "${tag}")
                ;;
            github.com )
                latest=$(_get_latest_github_tag "${owner}" "${repo}" "${extension}")
                remote_digest=$(_get_github_digest "${owner}" "${repo}" "${tag}" 'false')
                ;;
            * )
                logs="${logs}${dependency}\t Provider '${provider}' not supported, skipping\n"
                continue
        esac

        # compare digest and tag
        latest_base=$(echo "${latest}" | sed "s/${extension}$//g;s/^v//g;s/^V//g;")
        latest_expanded=$(_expand_version "${latest_base}" "${extension}")
        local_digest=$(read_update_stored_digest "${provider}/${owner}/${repo}" "v${version}${extension}" \
            "${remote_digest}") || { logs="${logs}${dependency}\t${local_digest}\n"; flag=1; break; }
        if [ -z "${latest}" ]; then
            logs="${logs}${dependency}\t No tags found, skipping\n"
        elif [ "${local_digest}" != "${remote_digest}" ]; then
            logs="${logs}${dependency}\t Different digest found: ${remote_digest}\n"
            flag=1
        elif [ "${version}${extension}" != "${latest_expanded}" ]; then
            logs="${logs}${dependency}\t Different version found: ${latest}\n"
            flag=1
        else
            logs="${logs}${dependency}\t Up to date\n"
        fi
    done

    # clean up digest file; remove all dependencies/version not present in configuration file
    clean_digest_file "${dependencies}"

    # format and display findings
    width=$((width + 2))
    tabs "${width}"
    printf "${logs}"

    return "${flag}"
}
