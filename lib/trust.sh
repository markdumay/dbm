#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly DOCKER_TRUST_DIR="${HOME}/.docker/trust"
readonly NOTARY_SERVER='https://notary.docker.io'
readonly NOTARY_CONFIG="${HOME}/.notary/config.json"
readonly NOTARY_JSON_CONFIG="{
    \"trust_dir\" : \"${DOCKER_TRUST_DIR}\",
    \"remote_server\": {
        \"url\": \"${NOTARY_SERVER}\"
    }
}"


#=======================================================================================================================
# Private Functions
#=======================================================================================================================

#=======================================================================================================================
# Derive the username of a given key filename. For example, the username 'signer' is derived from the input
# 'keys/signer.pub'.
#=======================================================================================================================
# Arguments:
#   $1 - Filename of the signer's key.
# Outputs:
#   Derived username, returns 1 in case of errors.
#=======================================================================================================================
_get_username_from_key() {
    key_file="$1"

    [ -z "${key_file}" ] && err "Key file required" && return 1
    [ ! -f "${key_file}" ] && err "Key file not found: ${key_file}" && return 1
    user=$(basename "${key_file}" | sed 's/\(.*\)\..*/\1/') # derive user name from key file without extension
    [ -z "${user}" ] && err "Cannot derive user name from key file: ${key_file}" && return 1
    
    echo "${user}"
    return 0
}

#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Add a signer to a Docker repository and initialize Docker Content Trust if needed. The name of the signer is derived
# from the public key's filename.
#=======================================================================================================================
# Arguments:
#   $1 - Owner of the repository.
#   $2 - Repository name.
#   $3 - Filename of the signer's public key.
# Outputs:
#   Initialized Docker Content Trust and authorized signer for the specified repository. Returns 1 in case of errors.
#=======================================================================================================================
add_repository_signer() {
    owner="$1"
    repository="$2"
    signer_key="$3"

    [ ! -f "${signer_key}" ] && err "Cannot find public key for signer: ${signer_key}" && return 1
    docker_is_logged_in || { err "Not logged in to Docker repository"; return 1; }

    signer=$(_get_username_from_key "${signer_key}") || return 1
    key_path=$(get_absolute_path "${app_basedir}" "${signer_key}")

    docker trust signer add --key "${key_path}" "${signer}" "${owner}/${repository}" || \
        { err "Cannot add trusted signer for repository: ${owner}/${repository}"; return 1; }

    return 0
}

#=======================================================================================================================
# Generate a public/private key for a user ready to be exported. All files are saved in the current directory by
# default. Existing files in the target directory are overwritten. Use add_repository_signer() to authorize the user
# for signing a specific repository. The function import_delegation_key() can import the generated private key to the
# local Docker Trust Store. The keys are valid for one year and use 2048-bit RSA encryption with SHA-256 certificate
# hashing. The following files are generated:
#   - Certificate Signing Request (.csr)
#   - Private key (.key)
#   - Certificate (.crt), equal to public key
#=======================================================================================================================
# Arguments:
#   $1 - Name of the delegate signer.
#   $2 - Passphrase for the key, generated if omitted.
#   $3 - Optional CSR fields to bypass interactive prompt, see openssl command.
#   $4 - Optional path where to move the files to, defaults to current directory.
# Outputs:
#   Generated delegate keys, returns the passphrase when successful. Returns 1 in case of errors.
#=======================================================================================================================
generate_delegate_key() {
    delegate="$1"
    passphrase="$2"
    subj="$3"
    path="$4"
    key_path='./'

    # validate delegate name, initialize passphrase, and initialize target directory
    [ -z "${delegate}" ] && err "Delegate name required" && return 1
    [ -z "${passphrase}" ] && passphrase=$(openssl rand -base64 32)
    if [ -n "${path}" ]; then
        key_path=$(get_absolute_path "${app_basedir}" "${path}")
        mkdir -p "${key_path}"
    fi

    key_file=$(get_absolute_path "${key_path}" "${delegate}.key")
    crt_file=$(get_absolute_path "${key_path}" "${delegate}.crt")
    csr_file=$(get_absolute_path "${key_path}" "${delegate}.csr")

    # generate the csr, private key and public certificate
    openssl genrsa -out "${key_file}" 2048
    cmd="openssl req -new -sha256 -key ${key_file} -out ${csr_file}"
    [ -n "${subj}" ] && cmd="${cmd} -subj '${subj}'"
    eval "${cmd}"
    openssl x509 -req -sha256 -days 365 -in "${csr_file}" -signkey "${key_file}" -out "${crt_file}"
    [ ! -f "${csr_file}" ] && err "Cannot create Certificate Signing Request (.csr): ${csr_file}" \
        && return 1
    [ ! -f "${key_file}" ] && err "Cannot create private key (.key) ${key_file}" && return 1
    [ ! -f "${crt_file}" ] && err "Cannot create certificate (.crt): ${crt_file}" && return 1

    # return the passphrase when successful
    echo "${passphrase}"
    return 0
}

#=======================================================================================================================
# Generate a public/private key for a user. The private key is installed in the local Docker Trust Store. By default, 
# the public key is saved in the current directory. Use add_repository_signer() to authorize the user to sign a specific
# repository.
#=======================================================================================================================
# Arguments:
#   $1 - Name of the signer.
#   $2 - Passphrase for the key, generated if omitted.
#   $3 - Optional path where to store the public key, defaults to current directory.
# Outputs:
#   Generated public/private signer keys, returns the passphrase when successful. Returns 1 in case of errors.
#=======================================================================================================================
generate_signer_key() {
    signer="$1"
    passphrase="$2"
    path="$3"
    key_path='./'


    # validate signer name, initialize passphrase, and initialize target directory
    [ -z "${signer}" ] && err "Signer name required" && return 1
    [ -z "${passphrase}" ] && passphrase=$(openssl rand -base64 32)
    if [ -n "${path}" ]; then
        key_path=$(realpath "${app_basedir}/${path}")
        mkdir -p "${key_path}"
    fi

    # generate the private and public signer keys
    pub_file=$(get_absolute_path "${key_path}" "${signer}.pub")
    cmd="docker trust key generate ${signer}"
    [ -n "${key_path}" ] && cmd="${cmd} --dir ${key_path}"
    
    # echo  "${cmd}" && return 1 
    
    export DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE="${passphrase}"
    eval "${cmd}" || { export DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE=''; return 1; }
    export DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE=''
    [ ! -f "${pub_file}" ] && err "Cannot find public key: ${pub_file}" && return 1

    # return the passphrase when successful
    echo "${passphrase}"
    return 0

    # move the public signer key to its destination if applicable
    # [ -n "${key_path}" ] && mv "${signer}.pub" "${key_path}/"
}

#=======================================================================================================================
# Import a private delegation key into the local trust store using the Notary client. The role name is derived from the
# file name of the delegation key, e.g. '~/.keys/user.key' becomes 'user'.
#=======================================================================================================================
# Arguments:
#   $1 - File name of the key to be imported.
#   $2 - Passphrase to be used by the Notary client, generated if omitted.
# Outputs:
#   Imported private key file, returns the passphrase when successful. Returns 1 in case of errors.
#=======================================================================================================================
import_delegation_key() {
    key_file="$1"
    passphrase="$2"
    [ -z "${key_file}" ] && err "Key file required" && return 1
    [ ! -f "${key_file}" ] && err "Key file not found: ${key_file}" && return 1
    [ -z "${passphrase}" ] && passphrase=$(openssl rand -base64 32)
    user=$(basename "${key_file}" | sed 's/\(.*\)\..*/\1/') # derive user name from key file without extension
    [ -z "${user}" ] && err "Cannot derive user name from key file: ${key_file}" && return 1
    
    # import the private key using the passphrase
    export NOTARY_DELEGATION_PASSPHRASE="${passphrase}"
    notary key import "${key_file}" --role "${user}" || { err "Cannot import private key: ${key_file}"; return 1; }

    # return the passphrase when successful
    echo "${passphrase}"
    return 0
}

#=======================================================================================================================
# Initialize the local notary client configuration for the current user, if not present already.
#=======================================================================================================================
# Outputs:
#   Initialized local Notary configuration file, returns 1 in case of errors.
#=======================================================================================================================
init_notary_config() {
    [ -f "${NOTARY_CONFIG}" ] && warn "Notary configuration already present" && return 1

    # Create the Notary configuration file
    path=$(dirname "${NOTARY_CONFIG}")
    mkdir -p "${path}" || { err "Cannot create directory for Notary configuration: ${path}"; return 1; }
    printf '%s' "${NOTARY_JSON_CONFIG}" > "${NOTARY_CONFIG}"

    # Verify the configuration file now exists
    if [ ! -f "${NOTARY_CONFIG}" ]; then
        err "Cannot create Notary configuration file: ${NOTARY_CONFIG}"
        return 1
    fi

    return 0
}

#=======================================================================================================================
# Remove a signer from a Docker repository. The name of the signer is derived from the public key's filename.
#=======================================================================================================================
# Arguments:
#   $1 - Owner of the repository.
#   $2 - Repository name.
#   $3 - Filename of the signer's public key or the signer name.
# Outputs:
#   Signer removed from the specified repository. Returns 1 in case of errors.
#=======================================================================================================================
remove_repository_signer() {
    owner="$1"
    repository="$2"
    signer_key="$3"

    [ -z "${signer_key}" ] && err "Public key or signer name required" && return 1
    docker_is_logged_in || { err "Not logged in to Docker repository"; return 1; }

    signer=$(_get_username_from_key "${signer_key}" 2> /dev/null ) || signer="${signer_key}"
    key_path=$(realpath "${app_basedir}/${signer_key}")

    docker trust signer remove "${signer}" "${owner}/${repository}" || \
        { err "Cannot removed trusted signer for repository: ${owner}/${repository}"; return 1; }

    return 0
}
