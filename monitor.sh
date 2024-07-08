#!/bin/sh

# NOTE we don't want 'set -e' because we need fine grain control over exiting
# with error
set -u

# TODO monitoring tasks
#
# Every minute:
# * check IMAP and SMTP availability
# * check IRC availability
#
# Every day:
# * check TLS cert expiry
#
# Every week or month:
# * check S.M.A.R.T. status on storage drives
#
# TODO add SOLUTION text to each PROBLEM

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
    swap_utilization="$(swapinfo | awk 'END { print(substr($5, 0, length($5)-1)) }')"
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
    #_print_check_header "TLS cert validity on all active ports"
    #openssl s_client -connect mail.empt.siva:465 -verify_return_error -x509_strict -verify_hostname mail.empt.siva < /dev/null
    #echo
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
