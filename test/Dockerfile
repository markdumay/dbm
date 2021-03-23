#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

#=======================================================================================================================
# Build arguments
#=======================================================================================================================
ARG BUILD_UID=1001
ARG BUILD_GID=1001
ARG BUILD_USER='dbm'
ARG BUILD_FLAGS=''
ARG BUILD_VERSION
ARG BUILD_TARGET='test'
ARG ALPINE_VERSION


#=======================================================================================================================
# Main image
#=======================================================================================================================
FROM alpine:"${ALPINE_VERSION?version}"

ARG BUILD_VERSION
ENV BUILD_VERSION "${BUILD_VERSION}"

# Copy helper scripts and test data
COPY utils/harden_alpine.sh /usr/local/sbin/
COPY test/docker-entrypoint.sh /usr/local/sbin/
COPY test/message.txt /

# Harden the image and assign access rights for key files and folders
# Note: ln is needed by entrypoint script
ARG BUILD_FLAGS
ARG BUILD_UID
ARG BUILD_GID
ARG BUILD_USER
RUN set -eu; \
    apk update -f; \
    apk --no-cache add -f grep shadow; \
    rm -rf /var/cache/apk/* /tmp; \
    chmod +x /usr/local/sbin/harden_alpine.sh; \
    chmod +x /usr/local/sbin/docker-entrypoint.sh; \
    /usr/local/sbin/harden_alpine.sh harden \
        -n "${BUILD_USER}" \
        -u "${BUILD_UID}" \
        -g "${BUILD_GID}" \
        -d /tmp \
        "${BUILD_FLAGS}";

# Run the container as non-root user
ARG BUILD_USER
USER "${BUILD_USER}"

ENTRYPOINT ["docker-entrypoint.sh"]