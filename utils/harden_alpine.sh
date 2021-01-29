#!/bin/sh
# Copyright 2020 Paul Morgan
# License: GPLv2 (https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
#
# Source: https://gist.githubusercontent.com/jumanjiman/f9d3db977846c163df12/raw/
#         9c88ada4af1df5fae66474b54b53fc4201e545f0/harden.sh
#
# Adapted by Mark Dumay on January 29th, 2021. 
# Usage ./harden.sh [USER] [UID] [flags]
# -   $1 - user name, defaults to 'user'
# -   $2 - user ID, defaults to '1000'
# -   $3 - group ID, defaults to '1000'
# -   $4 - optional flag, '--add-shell' keeps /bin/sh
#
# Modifications to original source:
# - Changed user and user ID to use command-line arguments instead of static definitions
# - Added check to see 'shadow' package is installed (needed to support Docker user namespaces)
# - Made /tmp writeable fo user
# - Removed duo security (not used by image)
# - Removed github_pubkeys (not used by image)
# - Added optional removal of shell
# - Applied shellcheck recommendations
# - Switched from 2 to 4 spaces for indentation
# - Standardized variable references where applicable (double quoting, dollar sign with bracelets)

# shellcheck disable=SC2086

set -x
set -e
#
# Docker build calls this script to harden the image during build.
#
# NOTE: To build on CircleCI, you must take care to keep the `find`
# command out of the /proc filesystem to avoid errors like:
#
#    find: /proc/tty/driver: Permission denied
#    lxc-start: The container failed to start.
#    lxc-start: Additional information can be obtained by \
#        setting the --logfile and --logpriority options.

user="$1"
uid="$2"
gid="$3"
flag="$4"
user=${user:-"user"}
uid=${uid:-"1000"}
gid=${gid:-"1000"}
[ "${flag}" = '--add-shell' ] && add_shell='true' || add_shell='false'


# Check shadow package is installed
if ! apk info -a shadow >/dev/null 2>&1; then
    echo 'The shadow package is required to support Docker''s user namespaces'
    echo 'For example, add below instruction to your Dockerfile:'
    echo '    RUN apk update -f && apk --no-cache add -f shadow && rm -rf /var/cache/apk/*'
fi

# Add user
/usr/sbin/groupadd -g "${gid}" "${user}"
/usr/sbin/useradd -D -s /bin/sh -g "${gid}" -u "${uid}" "${user}"
sed -i -r "s/^${user}:!:/${user}:x:/" /etc/shadow

# Be informative after successful login.
printf "\n\nApp container image built on %s." "$(date)" > /etc/mod

# Ensure /tmp is writable
mkdir -p /tmp
chown "${user}":"${user}" /tmp


# Improve strength of diffie-hellman-group-exchange-sha256 (Custom DH with SHA2).
# See https://stribika.github.io/2015/01/04/secure-secure-shell.html
#
# Columns in the moduli file are:
# Time Type Tests Tries Size Generator Modulus
#
# This file is provided by the openssh package on Fedora.
moduli=/etc/ssh/moduli
if [ -f "${moduli}" ]; then
    cp "${moduli}" "${moduli}.orig"
    awk '$5 >= 2000' "${moduli}.orig" > "${moduli}"
    rm -f "${moduli}.orig"
fi

# Remove existing crontabs, if any.
rm -fr /var/spool/cron
rm -fr /etc/crontabs
rm -fr /etc/periodic

# Remove all but a handful of admin commands.
find /sbin /usr/sbin ! -type d \
    -a ! -name nologin \
    -a ! -name setup-proxy \
    -a ! -name sshd \
    -a ! -name start.sh \
    -delete

# Remove world-writable permissions.
# This breaks apps that need to write to /tmp,
# such as ssh-agent.
find / -xdev -type d -perm +0002 -exec chmod o-w {} +
find / -xdev -type f -perm +0002 -exec chmod o-w {} +

# Remove unnecessary user accounts.
sed -i -r "/^(${user}|root|sshd)/!d" /etc/group
sed -i -r "/^(${user}|root|sshd)/!d" /etc/passwd

# Remove interactive login shell for everybody but user.
sed -i -r "/^${user}:/! s#^(.*):[^:]*\$#\1:/sbin/nologin#" /etc/passwd

readonly sysdirs='
    /bin 
    /etc 
    /lib 
    /sbin 
    /usr
'

# Remove apk configs.
find ${sysdirs} -xdev -regex '.*apk.*' -exec rm -fr {} +

# Remove crufty...
#   /etc/shadow-
#   /etc/passwd-
#   /etc/group-
find ${sysdirs} -xdev -type f -regex '.*-$' -exec rm -f {} +

# Ensure system dirs are owned by root and not writable by anybody else.
find ${sysdirs} -xdev -type d \
    -exec chown root:root {} \; \
    -exec chmod 0755 {} \;

# Remove all suid files.
find ${sysdirs} -xdev -type f -a -perm +4000 -delete

# Remove other programs that could be dangerous.
find ${sysdirs} -xdev \( \
    -name hexdump -o \
    -name chgrp -o \
    -name chmod -o \
    -name chown -o \
    -name ln -o \
    -name od -o \
    -name strings -o \
    -name su \
    \) -delete

# Remove shell if flagged to do so.
if [ "${add_shell}" != 'true' ]; then
    find ${sysdirs} -xdev \( \
        -name sh -o \
        \) -delete
fi

# Remove init scripts since we do not use them.
rm -fr /etc/init.d
rm -fr /lib/rc
rm -fr /etc/conf.d
rm -fr /etc/inittab
rm -fr /etc/runlevels
rm -fr /etc/rc.conf

# Remove kernel tunables since we do not need them.
rm -fr /etc/sysctl*
rm -fr /etc/modprobe.d
rm -fr /etc/modules
rm -fr /etc/mdev.conf
rm -fr /etc/acpi

# Remove root homedir since we do not need it.
rm -fr /root

# Remove fstab since we do not need it.
rm -f /etc/fstab

# Remove broken symlinks (because we removed the targets above).
find ${sysdirs} -xdev -type l -exec test ! -e {} \; -delete