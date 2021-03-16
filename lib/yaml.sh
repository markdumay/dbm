#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

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