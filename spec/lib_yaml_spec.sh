#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'lib/yaml.sh' yaml
    Include lib/yaml.sh

    Describe 'parse_yaml()'
        expected() { %text
            #|version="3.7"
            #|networks_dbm-test_name="dbm-test"
            #|services_dbm-test_image="markdumay/dbm-test:${BUILD_VERSION:?version}${IMAGE_SUFFIX:-}"
            #|services_dbm-test_container_name="dbm-test"
            #|services_dbm-test_restart="unless-stopped"
            #|services_dbm-test_networks+="dbm-test"
            #|services_alpine-test_image="alpine@${ALPINE_DIGEST}"
            #|services_alpine-test_container_name="alpine-test"
            #|services_alpine-test_restart="unless-stopped"
            #|services_alpine-test_command=">"
            #|services_alpine-test_networks+="dbm-test"
        }

        Parameters
            'test/docker-compose.yml' "$(expected)" success
            "$(uuidgen)" '' failure
        End

        It 'parses yaml files'
            When call parse_yaml "$1"
            The status should be "$3"
            The output should eq "$2"
        End
    End
End