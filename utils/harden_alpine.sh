#!/bin/sh

#=======================================================================================================================
# Title         : harden_alpine.sh
# Description   : Hardens a Linux Alpine instance.
# Author        : Mark Dumay
# Date          : February 15th, 2021
# Version       : 0.4.1
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
user_files=''
add_shell='false'
enable_read_only='false'
create_home='false'
remove_binaries=' hexdump; chgrp; chmod; chown; ln; od; sh; strings; su;'
allowed_binaries=' nologin; setup-proxy; sshd; start.sh;'
allowed_users="root|sshd"


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
    echo '  -u, --uid ID           Assigns ID to user (defaults to 1001)'
    echo '  -g, --gid ID           Assigns ID to group (defaults to 1001)'
    echo '  -v, --volume PATH      Prepares PATH to be volume mounted'
    echo '  -d, --dir PATH         Assigns ownership of PATH to user'
    echo '  -f, --file FILE        Assigns ownership of FILE to user'
    echo '  -k, --keep BINARY      Binary to keep'
    echo '  -U, --user NAME        User to keep'
    echo '  --add-shell            Adds shell access (/bin/sh) to instance'
    echo '  --create-home          Creates a home directory for the specified user'
    echo '  --read-only            Support read-only filesystem and tmpfs mounts'
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
# Displays a warning on console.
#=======================================================================================================================
# Arguments:
#   $1 - Warning to display.
# Outputs:
#   Writes  warning to stderr.
#=======================================================================================================================
warn() {
    printf "${RED}${BOLD}%s${NC}\n" "WARN: $1"
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
#   - user
#   - uid
#   - gid
#   - volume_dirs
#   - user_dirs
#   - user_files
#   - remove_binaries
#   - allowed_binaries
#   - allowed_users
#   - add_shell
#   - create_home
#   - enable_read_only
#   - command
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
parse_args() {
    id_set='false'

    # Process and validate command-line arguments (note: $1 is split using spaces if applicable)
    while [ -n "$1" ]; do
        case "$1" in
            -n | --name   ) shift; user="$1"; allowed_users="${allowed_users}|$1";;
            -u | --uid    ) shift; uid="$1"; id_set='true';;
            -g | --gid    ) shift; gid="$1"; id_set='true';;
            -v | --volume ) shift; volume_dirs="${volume_dirs} $1";;
            -d | --dir    ) shift; user_dirs="${user_dirs} $1";;
            -f | --file   ) shift; user_files="${user_files} $1";;
            -k | --keep   ) shift
                            remove_binaries=$(echo "${remove_binaries}" | sed "s/ $1;//g")
                            allowed_binaries="${allowed_binaries} $1;"
                            ;;
            -U | --user   ) shift; allowed_users="${allowed_users}|$1";;
            --add-shell   ) add_shell='true'; remove_binaries=$(echo "${remove_binaries}" | sed "s/ sh;//g");;
            --create-home ) create_home='true';;
            --read-only   ) enable_read_only='true';;
            harden        ) command="$1";;
            *             ) usage; terminate "Unrecognized parameter ($1)"
        esac
        shift
    done

    # Validate arguments
    fatal_error=''
    warning=''

    # Requirement 1 - a single value command is provided
    if [ -z "${command}" ]; then fatal_error='Expected command'
    # Requirement 2 - UID should be a positive number
    elif ! is_number "${uid}"; then fatal_error='UID is not a valid number'
    # Requirement 3 - GID should be a positive number
    elif ! is_number "${gid}"; then fatal_error='GID is not a valid number'
    # Requirement 3 - UID should be in range
    elif [ "${uid}" -lt 100 ] || [ "${uid}" -gt "${MAXID}" ]; then fatal_error="UID not in range 100 - ${MAXID}"
    # Requirement 4 - GID should be in range
    elif [ "${gid}" -lt 100 ] || [ "${gid}" -gt "${MAXID}" ]; then fatal_error="GID not in range 100 - ${MAXID}"
    # Warning 1 - user name not specified
    elif [ "${id_set}" = 'true' ] && [ "${user}" = '' ]; then warning='User name not specified, ignoring UID/GID'
    fi

    # Inform user and terminate on fatal error
    [ -n "${fatal_error}" ] && usage && terminate "${fatal_error}"
    [ -n "${warning}" ] && warn "${warning}"
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
        # do not create mail spool
        if ! grep -q 'CREATE_MAIL_SPOOL=no' /etc/default/useradd; then
            sed -i -r '/^CREATE_MAIL_SPOOL/d' /etc/default/useradd
        fi

        # create group and user
        /usr/sbin/groupadd -g "${gid}" "${user}"
        if [ "${create_home}" = 'true' ]; then
            /usr/sbin/useradd -m -s /bin/sh -g "${gid}" -u "${uid}" -d "/home/${user}" "${user}"
        else
            /usr/sbin/useradd -s /bin/sh -g "${gid}" -u "${uid}" "${user}"
        fi
        sed -i -r "s/^${user}:!:/${user}:x:/" /etc/shadow
    else
        warn 'No user name specified'
    fi
}

#=======================================================================================================================
# Assign ownership of specified folders and files to a specific user. The ownership of folders is recursive and includes
# their files. The following scenarios are considered.
#  - Volume mounts: Docker adapts the privileges and ownership of existing volumes. To ensure the data is accessible to 
#    the container, the UID and GID of the owner need to be consistent. The execute_assign_ownership() function creates
#    the local directory if needed, and assigns the specified user as owner. This ensures the volume mount is
#    initialized correctly at first use. Please note the ownership of volume mounts cannot be modified. The volume needs
#    to be recreated if the ownership needs to change.
#  - Tmpfs mounts: Tmpfs mounts can be used in a read-only filesystem to enable in-memory read/write access for specific
#    folders. In contrast to volume mounts, existing privileges and ownership are not adapted. The specified folder 
#    should not exist for tmpfs mounts to work correctly. Docker dynamically assigns ownership to the current user at
#    run time.
#=======================================================================================================================
# Arguments:
#   $1 - Volumes
#   $2 - Folders
#   $3 - Files
#   $4 - User name
# Outputs:
#   Reassigned ownership of folders and files.
#=======================================================================================================================
execute_assign_ownership() {
    print_status 'Assigning ownership of folders and files'

    # remove leading and trailing spaces
    volumes=$(echo "$1" | awk '{$1=$1};1')
    folders=$(echo "$2" | awk '{$1=$1};1')
    files=$(echo "$3" | awk '{$1=$1};1')
    username=$(echo "$4" | awk '{$1=$1};1')

    # display current settings
    display_volumes=$(echo "['${volumes}']" | sed 's/^\['\'' */\['\''/g' | sed 's/ /'\'', '\''/g')
    display_folders=$(echo "['${folders}']" | sed 's/^\['\'' */\['\''/g' | sed 's/ /'\'', '\''/g')
    display_files=$(echo "['${files}']" | sed 's/^\['\'' */\['\''/g' | sed 's/ /'\'', '\''/g')
    [ -n "${volumes}" ]  && log "Volumes:               ${display_volumes}"
    [ -n "${folders}" ]  && log "Folders:               ${display_folders}"
    [ -n "${files}" ]    && log "Files:                 ${display_files}"
    [ -n "${username}" ] && log "Username:              '${username}'"

    # create volume directories if needed and assign ownership recursively
    [ -n "${volumes}" ] && [ -n "${username}" ] && \
        log "Initalizing volume directories" && \
        eval "mkdir -p ${volumes}" && \
        eval "find ${volumes} -xdev -type d -exec chown ${username}:${username} {} \;" && \
        eval "find ${volumes} -xdev -type f -exec chown ${username}:${username} {} \;"

    # create regular directories if needed and assign ownership recursively
    if [ -n "${folders}" ] && [ -n "${username}" ]; then
        # if read only, warn if specified folders exist already and the user is not root
        if [ "${enable_read_only}" = 'true' ] && [ "${username}" != 'root' ]; then
            folders=$(eval "find ${folders} -xdev -type d 2> /dev/null")
            [ -n "${folders}" ] && warn "Found existing folders that might interfere with tmpfs mounts: ${folders}"
            [ -z "${folders}" ] && log 'Skipping initializing of regular directories, read-only mode'
        fi 

        # if not read-only or root, create specified folders and assign ownership recursively (excluding /etc/mtab)
        if [ "${enable_read_only}" != 'true' ] || [ "${username}" = 'root' ]; then
            log "Initalizing regular directories"
            eval "mkdir -p ${folders}" && \
            eval "find ${folders} -xdev -type d \( ! -wholename /etc/mtab \) -exec chown ${username}:${username} {} \;"
            eval "find ${folders} -xdev -type f \( ! -wholename /etc/mtab \) -exec chown ${username}:${username} {} \;"
        fi
    fi

    # assign ownership of files to specified user
    [ -n "${files}" ] && [ -n "${username}" ] && \
        log "Assigning ownership to files" && \
        eval "find ${files} -xdev -type f -exec chown ${username}:${username} {} \;"

    # warn if no user is specified
    [ -z "${username}" ] && warn 'No user name specified'
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
    bins=$(echo "${allowed_binaries}" | sed 's/ / -a ! -name /g' | sed 's/;//g')
    eval "find /sbin /usr/sbin ! -type d ${bins} -delete"
}

#TODO: fix this function
#=======================================================================================================================
# Remove world-writable permissions.
#=======================================================================================================================
# Outputs:
#   World-writable permissions removed.
#=======================================================================================================================
execute_remove_world_writable_permissions() {
    print_status 'Removing world-writable permissions'
    if [ "${enable_read_only}" = 'true' ]; then
        find / -xdev -type d -perm +0002 -exec chmod o-w {} +
        find / -xdev -type f -perm +0002 -exec chmod o-w {} +
    else
        log 'Skipped, image has enabled read-only file system'
    fi
}

# TODO: add flag to set nologin for all users
#=======================================================================================================================
# Remove unnecessary user accounts and interactive login shells.
#=======================================================================================================================
# Outputs:
#   User accounts removed and login shells disabled.
#=======================================================================================================================
execute_remove_accounts_and_logins() {
    print_status 'Removing unnecessary user accounts and interactive login shells'

    # Remove unnecessary user accounts
    sed -i -r "/^(${allowed_users})/!d" /etc/group
    sed -i -r "/^(${allowed_users})/!d" /etc/passwd

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
    eval set -- "$@" # unquote arguments
    parse_args "$@"

    # Display configuration settings
    display_volumes=$(echo "['${volume_dirs}']" | sed 's/^\['\'' */\['\''/g' | sed 's/ /'\'', '\''/g')
    display_dirs=$(echo "['${user_dirs}']" | sed 's/^\['\'' */\['\''/g' | sed 's/ /'\'', '\''/g')
    display_files=$(echo "['${user_files}']" | sed 's/^\['\'' */\['\''/g' | sed 's/ /'\'', '\''/g')
    display_bins=$(echo "['${remove_binaries}']" | sed 's/^\['\'' */\['\''/g' | sed 's/ /'\'', '\''/g' | sed 's/;//g')
    display_user_bins=$(echo "['${allowed_binaries}']" | sed 's/^\['\'' */\['\''/g' | sed 's/ /'\'', '\''/g' | \
                        sed 's/;//g')
    display_users=$(echo "['${allowed_users}']" | sed 's/|/'\'', '\''/g')
    print_status 'Hardening image with the following settings:'
    log "[User]"
    log "Main user name:        ${user}"
    log "Main user UID:         ${uid}"
    log "Main user GID:         ${gid}"
    log "Create user home:      ${create_home}"
    log "[File system]"
    log "Docker volumes:        ${display_volumes}"
    log "Main user dirs:        ${display_dirs}"
    log "Main user files:       ${display_files}"
    log "[Binaries]"
    log "Removed system bins:   ${display_bins}"
    log "Allowed user bins:     ${display_user_bins}"
    log "[Settings]"
    log "Read-only file system: ${enable_read_only}"
    log "Enabled users:         ${display_users}"
    log "Shell:                 ${add_shell}"

    # Execute workflows
    case "${command}" in
        harden)
            execute_add_user
            execute_assign_ownership '' "${SYSDIRS}" '' root
            execute_assign_ownership "${volume_dirs}" "${user_dirs}" "${user_files}" "${user}"
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