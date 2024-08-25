#!/bin/sh

# NOTE we don't want 'set -e' because we need fine grain control over exiting
# with error
set -u

# TODO remove traces of siva
# TODO monitoring tasks
#
# Every minute:
# * check IMAP and SMTP availability
# * check IRC availability
#
# Every week or month:
# * check S.M.A.R.T. status on storage drives
#
# TODO add SOLUTION text to each PROBLEM

# TODO display percentage and other numerical human metrics in the report:
# * load average percentages
# * swap usage
# * etc.
_every_minute() {
    _print_check_header "system load average"
    loadavg="$(sysctl -n vm.loadavg | awk '{ print $2*100, $3*100, $4*100 }')"
    read -r l1 l5 l15 <<EOF
${loadavg}
EOF
    if test "${l1}" -gt 90 -o "${l5}" -gt 90 -o "${l15}" -gt 90; then
        echo "PROBLEM: system load average exceeds threshold"
        rc=69 # EX_UNAVAILABLE
    fi
    echo

    _print_check_header "swap memory usage"
    # if there is no swap memory on the system, the last line will be a 'swapinfo' header.
    # $5 will be the string 'Capacity', so we use an awk trick (multiply by 1) to convert it into
    # a numerical 0.
    swap_utilization="$(swapinfo | awk 'END { print 1*substr($5, 0, length($5)-1) }')"
    if test "${swap_utilization}" -gt 10; then
        echo "PROBLEM: swap memory usage exceeds threshold"
        rc=69 # EX_UNAVAILABLE
    fi
    echo
}

_every_hour() {
    _print_check_header "ZFS pool status"
    zpoolstatus="$(zpool status -x)"
    echo "${zpoolstatus}"
    if test "${zpoolstatus}" != "all pools are healthy"; then
        echo "PROBLEM: ZFS pools are not healthy"
        rc=69 # EX_UNAVAILABLE
    fi
    echo

    # TODO finish
    # NOTE auth_level=3 disallows public keys < 256 bits
    # auth_level=4 seems optimal, but not sure about performance
    # suiteB_128_only forces ECC P-256
    tls_services="mail.empt.siva 465
mail.empt.siva 993
irc.empt.siva 443
irc.empt.siva 6697"
    _print_check_header "TLS cert validity on all active ports"
    while read -r host port; do
        cert="$(openssl s_client \
            -verify_return_error \
            -x509_strict \
            -auth_level 3 \
            -suiteB_128_only \
            -verify_hostname "${host}" \
            "${host}:${port}" < /dev/null 2>/dev/null)"
        if test "$?" -eq 0; then
            # Warn on expiry in the next 30 days
            if echo "${cert}" | openssl x509 -checkend 2592000 >/dev/null; then
                echo "TLS certificate for '${host}:${port}' is valid."
            else
                echo "PROBLEM: TLS certificate for '${host}:${port}' expires soon"
                rc=69 # EX_UNAVAILABLE
            fi
        else
            echo "PROBLEM: TLS certificate for '${host}:${port}' does not pass verification checks"
            rc=69 # EX_UNAVAILABLE
        fi
    done <<EOF
${tls_services}
EOF
    echo
}

_every_day() {
    _print_check_header "total disk usage"
    zpool list
    total_disk_usage="$(zpool get -Hpo value capacity zroot)"
    if test "${total_disk_usage}" -gt 75; then
        echo "PROBLEM: total disk usage exceeds threshold"
        rc=69 # EX_UNAVAILABLE
    fi
    echo
}

_print_check_header() {
    cat <<EOF
=========
Check: $1
=========
EOF
}

_print_report() {
    if test "${rc}" -eq 0; then
        msg="OK: No issues found."
    else
        msg="ERROR: ISSUES FOUND, see above."
    fi
    uptime="$(w -in)"

    cat <<EOF
=========
REPORT
=========
${msg}

Uptime:

${uptime}

EOF
}

_usage() {
    cat <<EOF
usage:
  monitor every_minute
  monitor every_hour
  monitor every_day
EOF
}

rc=0
case "$1" in
    every_minute)
        _every_minute
        ;;
    every_hour)
        _every_hour
        ;;
    every_day)
        _every_day
        ;;
    *)
        echo "$0: ERROR: unrecognized interval '$1'" >&2
        _usage >&2
        exit 64 # EX_USAGE
esac
_print_report
exit "${rc}"
