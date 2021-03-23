#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'cmd/root.sh' cmd
    Include lib/log.sh
    Include cmd/root.sh

    prepare() { set_log_color 'false'; }
    BeforeAll 'prepare'
    Todo 'parse_service()'
    Todo 'parse_args()'

    Describe 'usage()'
        It 'displays usage for DBM'
            When call usage
            The output should match pattern '?Docker Build Manager*'
        End
    End
End