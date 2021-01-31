#!/bin/sh

#=======================================================================================================================
# Title         : harden_alpine.sh
# Description   : Hardens a Linux Alpine instance.
# Author        : Mark Dumay
# Date          : January 31st, 2021
# Version       : 0.1.0
# Usage         : ./harden_alpine.sh [OPTIONS] COMMAND
# Repository    : https://github.com/markdumay/dbm.git
# License       : Copyright © 2021 Mark Dumay. All rights reserved.
#                 Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
# Credits       : Inspired by Hardening Gist from Paul Morgan (https://github.com/jumanjiman/)
# Comments      : Portions copyright Paul Morgan (jumanjiman), with GPLv2 License. Original source:
#                 https://gist.githubusercontent.com/jumanjiman/f9d3db977846c163df12/raw/
#                 9c88ada4af1df5fae66474b54b53fc4201e545f0/harden.sh
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly RED='\e[31m'                           # Red color
readonly NC='\e[m'                              # No color / reset
readonly BOLD='\e[1m'                           # Bold font
readonly MAXID=2147483647                       # Maximum ID supported for GID/UID (shadow package, newer versions 
                                                # support 4,294,967,296)
readonly MODULI='/etc/ssh/moduli'               # Moduli file for SSH
readonly SYSDIRS='/bin /etc /lib /sbin /usr'    # Pseudo array of system dirs, separated by spaces


#=======================================================================================================================
# Variables
#=======================================================================================================================
command=''
user=''
uid=1001
gid=1001
user_dirs=''
add_shell='false'
create_home='false'
remove_binaries=' hexdump; chgrp; chmod; chown; ln; od; sh; strings; su;'


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
    echo 'Script to harden a Linux Alpine instance'
    echo 
    echo "Usage: $0 COMMAND [OPTIONS]" 
    echo
    echo 'Commands:'
    echo '  harden                 Harden the current Linux Alpine instance'
    echo
    echo 'Options:'
    echo '  -n, --name NAME        Creates a user and group with specified name'
    echo '  -u, --uid ID           Assigns ID to user'
    echo '  -g, --gid ID           Assigns ID to group'
    echo '  -d, --dir PATH         Assigns ownership of PATH to user'
    echo '  -k, --keep BINARY      Binary to keep'
    echo '  --add-shell            Adds shell access (/bin/sh) to instance'
    echo '  --create-home          Creates a home directory for the specified user'
    echo '                         (not recommended for production)'
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
# Parse and validate the command-line arguments.
#=======================================================================================================================
# Globals:
#   - command
#   - user
#   - uid
#   - gid
#   - user_dirs
#   - add_shell
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
parse_args() {
    id_set='false'

    # Process and validate command-line arguments
    while [ -n "$1" ]; do
        case "$1" in
            -n | --name ) shift; user="$1";;
            -u | --uid  ) shift; uid="$1"; id_set='true';;
            -g | --gid  ) shift; gid="$1"; id_set='true';;
            -d | --dir  ) shift; user_dirs="${user_dirs} $1";;
            -k | --keep ) shift; remove_binaries=$(echo "${remove_binaries}" | sed "s/ $1;//g");;
            --add-shell ) add_shell='true'; remove_binaries=$(echo "${remove_binaries}" | sed "s/ sh;//g");; # keep 'sh'
            --create-home ) create_home='true';;
            harden      ) command="$1";;
            *           ) usage; terminate "Unrecognized parameter ($1)"
        esac
        shift
    done

    # Validate arguments
    fatal_error=''
    warning=''
    # Requirement 1 - a single value command is provided
    if [ -z "${command}" ]; then fatal_error="Expected command"
    # Requirement 2 - UID should be in range
    elif [ "${uid}" -lt 100 ] || [ "${uid}" -gt "${MAXID}" ]; then fatal_error="UID not in range 100 - ${MAXID}"
    # Requirement 3 - GID should be in range
    elif [ "${gid}" -lt 100 ] || [ "${gid}" -gt "${MAXID}" ]; then fatal_error="GID not in range 100 - ${MAXID}"
    # Warning 1 - user name not specified
    elif [ "${id_set}" = 'true' ] && [ "${user}" = '' ]; then warning='User name not specified, ugnoring UID/GID'
    fi

    # Inform user and terminate on fatal error
    [ -n "${fatal_error}" ] && usage && terminate "${fatal_error}"
    [ -n "${warning}" ] && log "WARN: ${warning}"
}

#=======================================================================================================================
# Validates prerequisites; shadow package needs to be installed to support Docker namespaces. The directory /tmp is
# created if needed.
#=======================================================================================================================
# Outputs:
#   Terminates with non-zero exit code on fatal error.
#=======================================================================================================================
validate_prerequisites() {
    # Check shadow package is installed
    if ! apk info -a shadow >/dev/null 2>&1; then
        log 'The shadow package is required to support Docker''s user namespaces'
        log 'For example, add below instruction to your Dockerfile:'
        log '    RUN apk update -f && apk --no-cache add -f shadow && rm -rf /var/cache/apk/*'
        terminate 'Could not satisfy prerequisites'
    fi

    # Ensure /tmp is available
    mkdir -p /tmp
}

#=======================================================================================================================
# Workflow Functions
#=======================================================================================================================

#=======================================================================================================================
# Add a user with specific UID and GID.
#=======================================================================================================================
# Outputs:
#   Added user, if user name is specified.
#=======================================================================================================================
execute_add_user() {
    print_status 'Adding user'
    if [ -n "${user}" ]; then
        /usr/sbin/groupadd -g "${gid}" "${user}"
        if [ "${create_home}" = 'true' ]; then
            /usr/sbin/useradd -m -s /bin/sh -g "${gid}" -u "${uid}" -d "/home/${user}" "${user}"
        else
            /usr/sbin/useradd -s /bin/sh -g "${gid}" -u "${uid}" "${user}"
        fi
        sed -i -r "s/^${user}:!:/${user}:x:/" /etc/shadow
    else
        log 'Skipped, no user name specified'
    fi
}

#=======================================================================================================================
# Assign ownership of specified folders and files to a specific user.
#=======================================================================================================================
# Arguments:
#   $1 - Folders
#   $2 - User name
# Outputs:
#   Reassigned ownership of folders and files.
#=======================================================================================================================
execute_assign_ownership() {
    print_status 'Assigning ownership of folders and files'
    if [ -n "$2" ]; then
        eval "find $1 -xdev -type d -exec chown -R $2:$2 {} \; -exec chmod -R 0755 {} \;"
    else
        log 'Skipped, no user name specified'
    fi
}

#=======================================================================================================================
# Updates message of the day.
#=======================================================================================================================
# Outputs:
#   Updated /etc/mod.
#=======================================================================================================================
execute_update_mod() {
    print_status 'Updating message of the day'
    printf "\n\nApp container image built on %s." "$(date)" > /etc/mod
}

#=======================================================================================================================
# Improves encryption strength of SSH moduli to custom DH with SHA2. 
# See https://stribika.github.io/2015/01/04/secure-secure-shell.html
#=======================================================================================================================
# Outputs:
#   Updated /etc/ssh/moduli.
#=======================================================================================================================
execute_improve_encryption() {
    print_status 'Updating SSH encryption strength'
    # Columns in the moduli file are:
    # Time Type Tests Tries Size Generator Modulus
    #
    # This file is provided by the openssh package on Fedora.
    if [ -f "${MODULI}" ]; then
        cp "${MODULI}" "${MODULI}.orig"
        awk '$5 >= 2000' "${MODULI}.orig" > "${MODULI}"
        rm -f "${MODULI}.orig"
    else
        log "Skipped, file '${MODULI}' not present"
    fi
}

#=======================================================================================================================
# Remove crontabs, if any.
#=======================================================================================================================
# Outputs:
#   Removed crontabs.
#=======================================================================================================================
execute_remove_crontabs() {
    print_status 'Removing crontabs'
    rm -fr /var/spool/cron
    rm -fr /etc/crontabs
    rm -fr /etc/periodic
}

#=======================================================================================================================
# Remove all but a handful of admin commands.
#=======================================================================================================================
# Outputs:
#   Admin commands removed from /sbin and /usr/sbin.
#=======================================================================================================================
execute_remove_admin_commands() {
    print_status 'Removing admin commands'
    find /sbin /usr/sbin ! -type d \
        -a ! -name nologin \
        -a ! -name setup-proxy \
        -a ! -name sshd \
        -a ! -name start.sh \
        -delete
}

#=======================================================================================================================
# Remove world-writable permissions.
#=======================================================================================================================
# Outputs:
#   World-writable permissions removed.
#=======================================================================================================================
execute_remove_world_writable_permissions() {
    print_status 'Removing world-writable permissions'
    find / -xdev -type d -perm +0002 -exec chmod o-w {} +
    find / -xdev -type f -perm +0002 -exec chmod o-w {} +
}

#=======================================================================================================================
# Remove unnecessary user accounts and interactive login shells.
#=======================================================================================================================
# Outputs:
#   User accounts removed and login shells disabled.
#=======================================================================================================================
execute_remove_accounts_and_logins() {
    print_status 'Removing unnecessary user accounts and interactive login shells'

    # Remove unnecessary user accounts
    sed -i -r "/^(${user}|root|sshd)/!d" /etc/group
    sed -i -r "/^(${user}|root|sshd)/!d" /etc/passwd

    # Remove interactive login shell for everybody but user
    sed -i -r "/^${user}:/! s#^(.*):[^:]*\$#\1:/sbin/nologin#" /etc/passwd
}

#=======================================================================================================================
# Clean other unnecessary files.
#=======================================================================================================================
# Outputs:
#   Unnecessary files removed.
#=======================================================================================================================
execute_clean_files() {
    print_status 'Cleaning other unnecessary files'

    # Remove apk configs
    log 'Removing apk configs'
    eval "find ${SYSDIRS} -xdev -regex '.*apk.*' -exec rm -fr {} +"

    # Remove crufty...
    #   /etc/shadow-
    #   /etc/passwd-
    #   /etc/group-
    log 'Removing crufty'
    eval "find ${SYSDIRS} -xdev -type f -regex '.*-$' -exec rm -f {} +"

    # Remove all suid files
    log 'Removing all suid files'
    eval "find ${SYSDIRS} -xdev -type f -a -perm +4000 -delete"

    # Remove other programs that could be dangerous
    log 'Removing unsafe binaries' 
    remove_binaries=$(echo "${remove_binaries}" | sed 's/ / -name /g' | sed 's/;/ -o/g')
    eval "find ${SYSDIRS} -xdev \( ${remove_binaries} \) -delete"

    # Remove init scripts since we do not use them
    log 'Removing init scripts'
    rm -fr /etc/init.d
    rm -fr /lib/rc
    rm -fr /etc/conf.d
    rm -fr /etc/inittab
    rm -fr /etc/runlevels
    rm -fr /etc/rc.conf

    # Remove kernel tunables since we do not need them
    log 'Removing kernel tunables'
    rm -fr /etc/sysctl*
    rm -fr /etc/modprobe.d
    rm -fr /etc/modules
    rm -fr /etc/mdev.conf
    rm -fr /etc/acpi

    # Remove root homedir since we do not need it
    log 'Removing root homedir'
    rm -fr /root

    # Remove fstab since we do not need it
    log 'Removing fstab'
    rm -f /etc/fstab

    # Remove broken symlinks (because we removed the targets above)
    log 'Removing broken symlinks'
    eval "find ${SYSDIRS} -xdev -type l -exec test ! -e {} \; -delete"
}


#=======================================================================================================================
# Main Script
#=======================================================================================================================

#=======================================================================================================================
# Entrypoint for the script.
#=======================================================================================================================
main() {
    # Parse arguments
    parse_args "$@"

    # Display configuration settings
    display_dirs=$(echo "['${user_dirs}']" | sed 's/^\['\'' */\['\''/g' | sed 's/ /'\'', '\''/g')
    display_bins=$(echo "['${remove_binaries}']" | sed 's/^\['\'' */\['\''/g' | sed 's/ /'\'', '\''/g' | sed 's/;//g')
    print_status 'Hardening image with the following settings:'
    log "  User:         ${user}"
    log "  UID:          ${uid}"
    log "  GID:          ${gid}"
    log "  User dirs:    ${display_dirs}"
    log "  Shell:        ${add_shell}"
    log "  User home:    ${create_home}"
    log "  Removed bins: ${display_bins}"

    # Execute workflows
    case "${command}" in
        harden)  
            validate_prerequisites
            execute_add_user
            execute_assign_ownership "${SYSDIRS}" root
            execute_assign_ownership "${user_dirs}" "${user}"
            execute_update_mod
            execute_improve_encryption
            execute_remove_crontabs
            execute_remove_admin_commands
            execute_remove_world_writable_permissions
            execute_remove_accounts_and_logins
            execute_clean_files
            ;;
        *)       
            terminate 'Invalid command'
    esac

    echo 'Done.'
}

main "$@"