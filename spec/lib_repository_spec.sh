#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'lib/repository.sh' repository
    Include lib/config.sh
    Include lib/log.sh
    Include lib/repository.sh
    Include lib/utils.sh

    # shellcheck disable=SC2034
    setup() { 
        set_log_color 'false'
        export TERM=xterm-256color # fix for macOS runner 
    }

    BeforeAll 'setup'

    Describe 'check_upgrades()'
        _get_docker_digest() { echo 'sha256:826f70e0ac33e99a72cf20fb0571245a8fee52d68cb26d8bc58e53bfa65dcdfa'; }
        _get_github_digest() { 
            case "$1" in
                restic | version ) echo 'sha:27f241334e9245a212bc2aba4956a5c0392e5940';;
                * )                echo 'sha:remote'
            esac
        }
        _get_latest_docker_tag() { 
            case "$2" in
                alpine )  echo '3.13.3';;
                * )       echo ''
            esac
            }
        _get_latest_github_tag() { 
            case "$1" in
                restic ) echo '0.12.0';;
                * )      echo '9.9.9'
            esac
        }
        clean_digest_file() { return 0; }
        read_update_stored_digest() { 
            case "$1" in
                hub.docker.com/_/alpine )    echo 'sha256:826f70e0ac33e99a72cf20fb0571245a8fee52d68cb26d8bc58e53bfa65dcdfa';;
                github.com/restic/restic )   echo 'sha:27f241334e9245a212bc2aba4956a5c0392e5940';;
                github.com/version/version ) echo 'sha:27f241334e9245a212bc2aba4956a5c0392e5940';;
                * )                          echo "sha:local"
            esac
        }

        Parameters
            '' '*No dependencies found*' success
            ';' '*No dependencies found*' success
            '11:RESTIC github.com restic restic 0.12.0;' '*Up to date*' success
            '11:VERSION github.com version version 0.12.0;' '*Different version found: 9.9.9*' failure
            '11:DIGEST github.com digest digest 0.12.0;' '*Different digest found: sha:remote*' failure
            '9:NO_TAG hub.docker.com _ no_tag 1.0.0;' '*No tags found, skipping*' success
            '9:ALPINE hub.docker.com _ alpine 3.13.3;' '*Up to date*' success
            '9:ALPINE 3.13.3;' '*Dependency has no repository link, skipping item*' failure
            '9:ALPINE xx 3.13.3;' '*Dependency is malformed, skipping item*' failure
            '9:ALPINE unsupported.com _ alpine 3.13.3;' "*Provider 'unsupported.com' not supported, skipping*" success
        End

        It 'checks upgrades correctly'
            When call check_upgrades "$1"
            The status should be "$3"
            The output should match pattern "$2"
        End
    End
End