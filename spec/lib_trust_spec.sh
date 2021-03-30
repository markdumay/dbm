#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'lib/trust.sh' trust
    conditions() { [ "${SHELLSPEC_SKIP_DOCKER}" = 'true' ] && echo "skip"; }
    Skip if 'function returns "skip"' [ "$(conditions)" = "skip" ]

    Include lib/log.sh
    Include lib/trust.sh
    Include lib/utils.sh

    # shellcheck disable=SC2034
    setup() { 
        set_log_color 'false'
    }

    BeforeAll 'setup'

    Describe '_get_username_from_key()'
        setup_local() {
            dummy_file=$(mktemp -t "signer.XXXXXXXXX")
            random_value=$(uuidgen)
        }

        cleanup_local() {
            [ -f "${dummy_file}" ] && rm -rf "${dummy_file}"
        }
        
        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            "${dummy_file}"   'signer' ''                           success
            "${random_value}" ''       'ERROR: Key file not found:' failure
            ''                ''       'ERROR: Key file require'    failure
        End

        It 'derives the username of a key file'
            When call _get_username_from_key "$1"
            The status should be "$4"
            The output should equal "$2"
            The error should start with "$3"
        End
    End


    # Todo 'add_repository_signer()'

    Describe 'generate_delegate_key()'
        setup_local() {
            dummy_file=$(mktemp -t "delegate-test.XXXXXXXXX")
            path=$(dirname "${dummy_file}")
        }

        cleanup_local() {
            [ -f "${dummy_file}" ] && rm -rf "${dummy_file}"
        }
        
        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            'delegate-test' '/O=DBM Trust Test' "${path}" '*Signature ok*Getting Private key*' success
        End

        It 'generates a delegate key'
            When call generate_delegate_key "$1" "$2" "$3"
            The status should be "$5"
            The error should match pattern "$4"
        End
    End

    Describe 'generate_signer_key()' test
        setup_local() {
            dummy_file=$(mktemp -t "signer-test.XXXXXXXXX")
            path=$(dirname "${dummy_file}")
        }

        # TODO: clean private key
        cleanup_local() {
            [ -f "${dummy_file}" ] && rm -rf "${dummy_file}"
        }
        
        BeforeAll 'setup_local'
        AfterAll 'cleanup_local'

        Parameters
            'signer-test' "${path}" success
        End

        It 'generates a signer key'
            When call generate_signer_key "$1" "$2"
            The status should be "$3"
            # The error should match pattern "$4"
            Dump
        End
    End

    # Todo 'import_delegation_key()'
    # Todo 'init_notary_config()'
    # Todo 'remove_repository_signer()'
End