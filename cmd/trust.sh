#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly usage_trust_msg_short="
Usage:
  dbm trust <add|revoke|import> KEY [flags]
  dbm trust generate <signer|delegate> NAME [flags]
" 

readonly usage_trust_msg_full="
Trust initializes Docker Content Trust for a Docker repository and authorizes
one or more users to sign images within the repository. Signing is specific to
each tagged image. Use the 'add' subcommand to authorize specific users,
identified by a public key, to sign images. Use the 'revoke' subcommand to
remove the privileges. Use the 'generate' and 'import' subcommands to create or
import keys. Run '--help' for each subcommand for more details.

${usage_trust_msg_short}

Commands:
  add                         Authorize a user to sign images
  revoke                      Revoke authorization of a user to sign images
  generate                    Generate a public/private key pair for a user
  import                      Import the private key of a user

Global Flags:
      --config <file>         Config file to use (defaults to dbm.ini)
      --no-digest             Skip validation of digests
  -h, --help                  Help for the trust command

"

readonly usage_trust_add_msg_short="
Usage:
  dbm trust add KEY [flags]
"

readonly usage_trust_add_msg_full="
Add authorizes a specific user to sign images of the Docker repository. It
requires the public key of the user. Use the 'generate' command to generate
the public/private key pair for a user. The username is derived from the public
key file. 

${usage_trust_add_msg_short}

Examples:
  dbm trust add keys/signer.pub
  Authorizes the user 'signer' identified by the 'signer.pub' public key in the 'keys'
  folder to sign images.

Global Flags:
      --config <file>         Config file to use (defaults to dbm.ini)
      --no-digest             Skip validation of digests
  -h, --help                  Help for the trust command

"

readonly usage_trust_revoke_msg_short="
Usage:
  dbm trust revoke NAME [flags]
"

readonly usage_trust_revoke_msg_full="
Revoke removes the authorization of a specific user to sign images of the
Docker repository. It requires the name of the user to be revoked. If a filename
is provided instead, the username is derived from the filename.

${usage_trust_revoke_msg_short}

Examples:
  dbm trust revoke keys/signer.pub
  Removes the authorization of the user 'signer' to sign images.

  dbm trust revoke user
  Removes the authorization of 'user' to sign images.

Global Flags:
      --config <file>         Config file to use (defaults to dbm.ini)
      --no-digest             Skip validation of digests
  -h, --help                  Help for the trust command

"

readonly usage_trust_generate_msg_short="
Usage:
  dbm trust generate <signer|delegate> NAME [flags]
"

readonly usage_trust_generate_msg_full="
Generate creates a public/private key pair for a specific user. A user can be
either a signer or a delegate. The private key of a 'signer' is added to the
local Docker Content Trust store. By default, the public key is saved in the
current directory. The private key of a 'delegate' is not added to local Docker
Content Store. Instead, the private key, public key, and certificate signing
request of the user are saved in current folder. The private key can be
imported using the 'import' command. The keys are valid for one year and use
2048-bit RSA encryption with SHA-256 certificate hashing. 

${usage_trust_generate_msg_short}

Examples:
  dbm trust generate signer user
  Generates a public/private key pair for 'user' and imports the private key
  into the local Docker Content Trust Store. The public key is saved in the
  current directory.

  dbm trust generate delegate user
  Generates a public/private key pair for 'user' and saves the files in the
  current directory.

Global Flags:
      --config <file>         Config file to use (defaults to dbm.ini)
      --no-digest             Skip validation of digests
  -h, --help                  Help for the trust command

"

readonly usage_trust_import_msg_short="
Usage:
  dbm trust import KEY [flags]
"

readonly usage_trust_import_msg_full="
Generate creates a public/private key pair for a specific user. A user can be
either a signer or a delegate. The private key of a 'signer' is added to the
local Docker Content Trust store. By default, the public key is saved in the
current directory.

The private key of a 'delegate' is not added to local Docker Content Store.
Instead, the private key, public key, and certificate signing request of the
user are saved in current folder. The private key can be imported using the
'import' command. The keys are valid for one year and use 2048-bit RSA
encryption with SHA-256 certificate hashing. 

${usage_trust_generate_msg_short}

Examples:
  dbm trust generate signer user
  Generates a public/private key pair for 'user' and imports the private key
  into the local Docker Content Trust Store. The public key is saved in the
  current directory.

  dbm trust generate delegate user
  Generates a public/private key pair for 'user' and saves the files in the
  current directory.

Global Flags:
      --config <file>         Config file to use (defaults to dbm.ini)
      --no-digest             Skip validation of digests
  -h, --help                  Help for the trust command

"

#=======================================================================================================================
# Functions
#=======================================================================================================================

#=======================================================================================================================
# Execute a trust command for a single repository. The following trust commands are supported: add, import, revoke, and
# generate.
#=======================================================================================================================
# Arguments:
#   $1 - Repository owner.
#   $2 - Repository name.
#   $3 - Subcommand, either add, generate, import, or revoke.
#   $4 - Key type, either delegate or signer.
#   $5 - Key file or user name.
# Outputs:
#   Executed trust command, or a non-zero result in case of errors.
#=======================================================================================================================
execute_trust_repository() {
    owner="$1"
    repository="$2"
    subcommand="$3"
    key_type="$4"
    key_file="$5"

    case "${subcommand}" in
        add )       print_status "Adding repository signer"
                    add_repository_signer "${owner}" "${repository}" "${key_file}" || return 1;;
        import )    print_status "Importing delegate key"
                    import_delegation_key "${key_file}" '' || return 1;;
        revoke )    print_status "Revoking signer privileges"
                    remove_repository_signer "${owner}" "${repository}" "${key_file}" || return 1;;
        generate )  print_status "Generating signer/delegate key"
                    generate_key "${key_type}" "${key_file}";;
        * )         err "Command not supported: ${subcommand}"; return 1
    esac

    return 0
}

#=======================================================================================================================
# Execute a trust command for multiple repositories, derived from a list of selected images. The following trust
# commands are supported: add, import, revoke, and generate.
#=======================================================================================================================
# Arguments:
#   $1 - Images to trust, separated by a newline '\n'.
#   $2 - Subcommand, either add, generate, import, or revoke.
#   $3 - Key type, either delegate or signer.
#   $4 - Key file or user name.
# Outputs:
#   Executed trust command, or a non-zero result in case of errors.
#=======================================================================================================================
# TODO: refine services?
execute_trust() {
    images="$1"
    subcommand="$2"
    key_type="$3"
    key_file="$4"

    # Execute trust command for each identified owner/repository (derived from images)
    IFS=' '
    for image in $images; do
        owner=$(echo "${image}" | awk -F'/' '{print $1}')
        repository=$(echo "${image}" | awk -F':' '{print $1}' | awk -F'/' '{print $2}')
        execute_trust_repository "${owner}" "${repository}" "${subcommand}" "${key_type}" "${key_file}" || return 1
    done

    return 0
}

#=======================================================================================================================
# Parse and validate the command-line arguments for the trust command.
#=======================================================================================================================
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, returns 1 on fatal error.
#=======================================================================================================================
# shellcheck disable=SC2034
parse_trust_args() {
    error=''

    # Ignore first argument, which is the 'trust' command
    shift

    # Capture any additional flags
    while [ -n "$1" ] && [ -z "${error}" ] ; do
        case "$1" in
            add | import | revoke ) arg_subcommand="$1";;
            generate )              arg_subcommand="$1";;
            signer | delegate )     arg_key_type="$1";;
            --config )              shift; [ -n "$1" ] && arg_config="$1" || error="Missing config filename";;
            --no-digest )           arg_no_digest='true';;
            -h | --help )           usage_trust 'false'; exit;;
            * )                     arg_key_file=$(parse_arg "$1") || error="Argument not supported: ${arg_key_file}"
        esac
        [ -n "$1" ] && shift
    done

    # Validate arguments
    [ -z "${arg_subcommand}" ] && error="Expected command"
    [ "${arg_subcommand}" = 'generate' ] && [ -z "${arg_key_type}" ] \
        && error="Expected key type (signer or delegate)" && arg_key_file=''
    [ "${arg_subcommand}" = 'generate' ] && [ -z "${arg_key_file}" ] && [ -z "${error}" ] \
        && error="Expected name"
    [ -z "${arg_key_file}" ] && [ -z "${error}" ] && error="Expected key filename"
    [ -n "${error}" ] && usage_trust 'true' && err "${error}" && return 1
    return 0
}

#=======================================================================================================================
# Display usage message for the trust command.
#=======================================================================================================================
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage_trust() {
    short="$1"
    full_msg=''
    short_msg=''

    case "${arg_subcommand}" in
        add )      full_msg="${usage_trust_add_msg_full}"; short_msg="${usage_trust_add_msg_short}";;
        revoke )   full_msg="${usage_trust_revoke_msg_full}"; short_msg="${usage_trust_revoke_msg_short}";;
        generate ) full_msg="${usage_trust_generate_msg_full}"; short_msg="${usage_trust_generate_msg_short}";;
        import )   full_msg="${usage_trust_import_msg_full}"; short_msg="${usage_trust_import_msg_short}";;
        * )        full_msg="${usage_trust_msg_full}"; short_msg="${usage_trust_msg_short}";;
    esac

    [ "${short}" = 'true' ] && echo "${short_msg}" || echo "${full_msg}"
}