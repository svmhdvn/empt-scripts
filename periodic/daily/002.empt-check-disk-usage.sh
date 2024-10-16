#!/bin/sh

check_disk_usage() {
    total_disk_usage="$(zpool get -Hpo value capacity zroot)"
    cat <<EOF
===== EMPT: check total disk usage =====

Disk "zroot": ${total_disk_usage}% used

EOF
    if test "${total_disk_usage}" -gt 75; then
        echo "PROBLEM: total disk usage exceeds threshold"
        exit 69 # EX_UNAVAILABLE
    fi
}

if test -r /etc/defaults/periodic.conf; then
    . /etc/defaults/periodic.conf
    source_periodic_confs
fi

case "${daily_empt_check_disk_usage_enable:-NO}" in
    [Yy][Ee][Ss]) check_disk_usage ;;
    *) ;;
esac
