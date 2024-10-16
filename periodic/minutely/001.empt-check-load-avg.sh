#!/bin/sh

check_load_avg() {
    loadavg="$(sysctl -n vm.loadavg | awk '{ print $2*100, $3*100, $4*100 }')"
    read -r l1 l5 l15 <<EOF
${loadavg}
EOF
    cat <<EOF
===== EMPT: check load average =====
last 1 minute: ${l1}%
last 5 minute: ${l5}%
last 15 minute: ${l15}%

EOF
    if test "${l1}" -gt 90 -o "${l5}" -gt 90 -o "${l15}" -gt 90; then
        echo "PROBLEM: system load average exceeds threshold"
        exit 69 # EX_UNAVAILABLE
    else
        echo "OK"
    fi
}

if test -r /etc/defaults/periodic.conf; then
    . /etc/defaults/periodic.conf
    source_periodic_confs
fi

case "${minutely_empt_check_load_avg_enable:-NO}" in
    [Yy][Ee][Ss]) check_load_avg ;;
    *) ;;
esac
