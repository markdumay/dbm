#!/bin/sh

#=======================================================================================================================
# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

Describe 'lib/trust.sh' docker trust
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
            The output should start with "$2"
            The error should start with "$3"
        End
    End


    # Todo 'add_repository_signer()'

    Describe 'generate_delegate_key()'
        setup_local_delegate() {
            dummy_file=$(mktemp -t "delegate-test.XXXXXXXXX")
            dummy_file=$(echo "${dummy_file}" | sed 's|/delegate-test.XXXXXXXXX.|/delegate-test.|g') # macOS/mktemp fix
            path=$(dirname "${dummy_file}")
        }

        cleanup_local_delegate() {
            { [ -f "${path}/delegate-test.crt" ] && rm -rf "${path}/delegate-test.crt"; } || true
            { [ -f "${path}/delegate-test.csr" ] && rm -rf "${path}/delegate-test.csr"; } || true
            { [ -f "${path}/delegate-test.key" ] && rm -rf "${path}/delegate-test.key"; } || true
        }
        
        BeforeAll 'setup_local_delegate'
        AfterAll 'cleanup_local_delegate'

        Parameters
            'delegate-test' '' "${path}" '/O=DBM Trust Test' '*Signature ok*Getting Private key*' 'Generated passphrase:*' success
        End

        It 'generates a delegate key'
            When call generate_delegate_key "$1" "$2" "$3" "$4"
            The status should be "$7"
            The error should match pattern "$5"
            The output should match pattern "$6"
            Dump
        End
    End

    Describe 'generate_signer_key()'
        setup_local_signer() {
            dummy_file=$(mktemp -t "signer-test.XXXXXXXXX")
            dummy_file=$(echo "${dummy_file}" | sed 's|/signer-test.XXXXXXXXX.|/signer-test.|g') # macOS/mktemp fix
            path=$(dirname "${dummy_file}")
        }

        cleanup_local_signer() {
            { [ -f "${path}/signer-test.pub" ] && rm -rf "${path}/signer-test.pub"; } || true
        }
        
        BeforeAll 'setup_local_signer'
        AfterAll 'cleanup_local_signer'

        Parameters
            'signer-test' '' "${path}" success
        End

        It 'generates a signer key'
            When call generate_signer_key "$1" "$2" "$3"
            The status should be "$4"
            The output should match pattern "*Corresponding public key available: *signer-test.pub*"
        End
    End

    # Todo 'import_delegation_key()'
    # Todo 'init_notary_config()'
    # Todo 'remove_repository_signer()'
End