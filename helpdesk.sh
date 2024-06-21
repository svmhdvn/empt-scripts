#!/bin/sh
set -eu

# =============================================================================
# COMMON UTILITY FUNCTIONS
# =============================================================================

# Converts an RFC 5322 address-list to a list of UNIX usernames
_address_list_to_usernames() {
    awk -v RS=',' '{ split($NF, parts, "@"); sub("<", "", parts[1]); print parts[1] }'
}

# $1 = line
# $2 = file
_append_if_missing() {
    grep -qxF "$1" "$2" || echo "$1" >> "$2"
}

_helpdesk_reply() {
    # TODO figure out the proper way to use DMA without using the absolute command
    {
        cat <<EOF
To: ${HELPDESK_FROM}
Subject: [HELPDESK] Re: ${HELPDESK_SUBJECT}
In-Reply-To: ${HELPDESK_MESSAGE_ID}
References: ${HELPDESK_REFERENCES} ${HELPDESK_MESSAGE_ID}
${HELPDESK_CC:+Cc: "${HELPDESK_CC}"}

EOF
        cat
    } | /usr/libexec/dma -f 'it@empt.siva' -t
}

# =============================================================================
# DASHBOARD
# =============================================================================

# $1 = dataset
_display_dataset_quota() {
    pretty_props="$(zfs list -Ho used,available "$1")"
    raw_props="$(zfs list -Hpo used,available "$1")"
    read -r used_pretty available_pretty <<EOF
${pretty_props}
EOF
    read -r used_raw available_raw <<EOF
${raw_props}
EOF
    printf "${used_pretty} / ${available_pretty} ($((used_raw * 100 / available_raw))%)"
}

_groups_storage() {
    for g in $(jexec -l cifs groups "${HELPDESK_FROM_USER}"); do
        test "${g}" = "${HELPDESK_FROM_USER}" && continue
        quota="$(_display_dataset_quota "zroot/empt/synced/rw/group:${g}")"
        echo "  ${g} = ${quota}"
    done
}

dashboard_usage() {
    cat <<EOF
usage:
    dashboard
EOF
}

helpdesk_dashboard() {
    user_quota="$(_display_dataset_quota zroot/empt/synced/rw/human:${HELPDESK_FROM_USER})"
    group_quotas="$(_groups_storage)"

    _helpdesk_reply <<EOF
DASHBOARD
=========

My storage = ${user_quota}

My groups:
${group_quotas}
EOF
}

# =============================================================================
# GROUPS
# =============================================================================

# TODO
# * Create a shared calendar
# * Create a group-private IRC channel (possibly with a shared password)
# * Ensure that a group is not created with the same name as a user just for sanity

groups_usage() {
    cat <<EOF
usage:
    groups.sh list
    groups.sh invite <groupname>
    groups.sh quota <groupname> <newquota>

environment: HELPDESK_*
EOF
}

groups_list() {
    groups="$(jexec -l cifs groups "${HELPDESK_FROM_USER}")"
    readonly groups

    _helpdesk_reply <<EOF
You are a part of these groups:

${groups}
EOF
}

groups_invite() {
    # Take the new group name as the last word of the subject line
    group_name="$1"
    readonly group_name

    # If the group doesn't exist, then get the next available GID
    if shown_group="$(jexec -l cifs pw groupshow "${group_name}" -q)"; then
        group_gid="$(echo "${shown_group}" | cut -f 3 -d :)"
    else
        group_gid="$(jexec -l cifs pw groupnext)"
    fi
    readonly group_gid

    for j in cifs radicale; do
        # TODO idempotency
        jexec -l "${j}" pw groupadd -g "${group_gid}" -n "${group_name}" -q || true
    done

    # Create a mailing list for the group if it doesn't already exist
    # ============================================================

    if ! test -d "/var/spool/mlmmj/${group_name}"; then
        # TODO remove need for answer file
        # TODO fix owner and figure out how that's going to work
        cat > /empt/jails/mail/tmp/mlmmj-answers.txt <<EOF
SPOOLDIR='/var/spool/mlmmj'
LISTNAME='${group_name}'
FQDN='empt.siva'
OWNER='postmaster@empt.siva'
TEXTLANG='en'
ADDALIAS='n'
DO_CHOWN='n'
CHOWN=''
ADDCRON='n'
EOF

        jexec -l -U mlmmj mail mlmmj-make-ml -f /tmp/mlmmj-answers.txt
        rm -f /empt/jails/mail/tmp/mlmmj-answers.txt
    fi

    # Set the upstream mail relayhost
    mail_jid="$(jls -j mail jid)"
    readonly mail_jid
    echo "fe80::eeee:${mail_jid}%lo0" | jexec -l -U mlmmj mail tee "/var/spool/mlmmj/${group_name}/control/relayhost"

    # Ensure that users cannot sub/unsub directly from the mailinglist
    jexec -l -U mlmmj mail touch "/var/spool/mlmmj/${group_name}/control/closedlist"

    # add the new mailing lists to the postfix maps
    _append_if_missing "${group_name}@empt.siva ${group_name}@localhost.mlmmj" /empt/jails/mail/usr/local/etc/postfix/mlmmj_aliases
    _append_if_missing "${group_name}@localhost.mlmmj mlmmj:${group_name}" /empt/jails/mail/usr/local/etc/postfix/mlmmj_transport
    for m in mlmmj_aliases mlmmj_transport; do
        jexec -l mail postmap "/usr/local/etc/postfix/${m}"
    done

    # Create a storage dataset for the group and mount it in corresponding jails
    # ==========================================================================

    # TODO do we need a reservation? I don't think so
    group_mount="/empt/synced/rw/groups/${group_name}"
    readonly group_mount

    zfs create -p \
        -o quota=1G \
        -o mountpoint="${group_mount}" \
        "zroot/empt/synced/rw/group:${group_name}"

    # Create the data and mountpoint directories
    for d in "${group_mount}/home" "${group_mount}/diary" "/empt/jails/cifs/groups/${group_name}"; do
        install -d -o root -g "${group_gid}" -m 1770 "${d}"
    done

    # Mount the group storage in cifs
    cifs_mount_src="${group_mount}/home"
    readonly cifs_mount_src
    cifs_mount_dst="/empt/jails/cifs/groups/${group_name}"
    readonly cifs_mount_dst
    _append_if_missing "${cifs_mount_src} ${cifs_mount_dst} nullfs rw 0 0" /empt/synced/rw/fstab.d/cifs.fstab
    # TODO idempotency and proper error handling
    mount -t nullfs "${cifs_mount_src}" "${cifs_mount_dst}" 2>/dev/null || true

    # TODO radicale
    # ==========================================================================

    # TODO join the user to the IRC channel and subscribe the IRC logging bot

    # Invite the users to all of the groups' resources
    # ================================================
    other_members="$(echo "${HELPDESK_CC}" | _address_list_to_usernames)"
    readonly other_members

    comma_separated_members="$(printf '%s\n%s\n' "${HELPDESK_FROM_USER}" "${other_members}" | paste -s -d, -)"
    readonly comma_separated_members

    for j in cifs radicale; do
        jexec -l "${j}" pw groupmod -n "${group_name}" -m "${comma_separated_members}" -q || true
    done

    for u in ${HELPDESK_FROM_USER} ${other_members}; do
        jexec -l -U mlmmj mail /usr/local/bin/mlmmj-sub -L "/var/spool/mlmmj/${group_name}" -a "${u}@empt.siva" -cfs
    done
    # ================================================

    # create a welcome file
    jexec -l cifs install -o "${HELPDESK_FROM_USER}" -g "${group_name}" -m 0660 /dev/null "/groups/${group_name}/WELCOME.txt"
    echo "Welcome to the '${group_name}' group!" > "${cifs_mount_src}/WELCOME.txt"

    _helpdesk_reply <<EOF
You are now part of the new group '${group_name}'!
EOF
}

# $1 = group name
# $2 = requested quota (in whole number GiB units)
# Assumes that IT has already verified that there is enough storage to support
# this request
# TODO if IT has already moderated and checked this request manually, does it
# matter that we do all this input validation programmatically?
groups_quota() {
    # Ensure the group dataset exists
    group_dataset="zroot/empt/synced/rw/group:$1"
    readonly group_dataset
    if ! zfs list -H -o name "${group_dataset}"; then
        echo "$0: ERROR: nonexistent dataset for group '$1'" >&2
        exit 65 # EX_DATAERR
    fi

    # Ensure that the requested quota is a whole number
    case "$2" in
        ''|0*|*[!0-9]*)
            echo "$0: ERROR: invalid requested quota '$2'" >&2
            exit 65 # EX_DATAERR
    esac

    zfs set "quota=${2}G" "${group_dataset}"
    _helpdesk_reply <<EOF
Group '${group_name}' now has a maximum storage allowance of ${2} GiB.
EOF
}

helpdesk_groups() {
    case "$1" in
        list|show) _list ;;
        create|invite|form) _invite "$2" ;;
        quota) _quota "$2" "$3" ;;
        *)
            echo "$0: ERROR: invalid verb '$1'" >&2
            _usage >&2
            exit 64 # EX_USAGE
    esac
}

# =============================================================================
# HELPDESK USAGE GUIDE
# =============================================================================

helpdesk_usage() {
    _helpdesk_reply <<EOF
EOF
}


# =============================================================================
# HELPDESK MAIN
# =============================================================================
while getopts c:f:m:r:s: flag; do
    case "${flag}" in
        c)
            cc="${OPTARG}"
            ;;
        f)
            from="${OPTARG}"
            ;;
        m)
            message_id="${OPTARG}"
            ;;
        r)
            references="${OPTARG}"
            ;;
        s)
            subject="${OPTARG}"
            ;;
        *)
            echo "$0: ERROR: unknown flag '${flag}'" >&2
            usage >&2
            exit 64 # EX_USAGE
    esac
done

from_user="$(echo "${from}" | _address_list_to_usernames)"
if test -z "${from_user}"; then
    echo "$0: ERROR: invalid flag value -f '${from}'" >&2
    usage >&2
    exit 64 # EX_USAGE
fi

# parse the subject line
read -r verb object param1 param2 <<EOF
${subject}
EOF

# triage the task based on the type of object
case "${object}" in
    group*)
        helpdesk_groups "${verb}" "${param1}" "${param2}"
        ;;
    dashboard)
        helpdesk_dashboard
        ;;
    *)
        helpdesk_usage
        ;;
esac
