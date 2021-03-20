#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/info.sh'
    Include lib/log.sh
    Include cmd/root.sh
    Include cmd/info.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'

    Todo 'execute_show_info'
    Todo 'parse_info_args'
    Todo 'usage_info'
End