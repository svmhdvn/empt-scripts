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
# * monitor the uptime in some way if possible, ensure no sporadic reboots
#
# Every week or month:
# * check S.M.A.R.T. status on storage drives
#
# TODO add SOLUTION text to each PROBLEM

_every_minute() {
    _print_check_header "system load average"
    if ! /usr/local/libexec/nagios/check_load -r -w 0.90 -c 0.95; then
        echo "PROBLEM: system load average exceeds threshold"
        rc=69 # EX_UNAVAILABLE
    fi
    echo

    _print_check_header "swap memory usage"
    if ! /usr/local/libexec/nagios/check_swap -w 90% -c 50%; then
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
        rc=64 # EX_USAGE
esac

if test "${rc}" -ne 0; then
    _print_report
    exit "${rc}"
fi
