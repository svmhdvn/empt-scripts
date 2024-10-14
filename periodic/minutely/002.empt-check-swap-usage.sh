#!/bin/sh

check_swap_usage() {
    # if there is no swap memory on the system, the last line will be a 'swapinfo' header.
    # $5 will be the string 'Capacity', so we use an awk trick (multiply by 1) to convert it into
    # a numerical 0.
    swap_utilization="$(swapinfo | awk 'END { print 1*substr($5, 0, length($5)-1) }')"
    cat <<EOF
===== EMPT: check swap usage =====
Current swap usage: ${swap_utilization}%

EOF
    if test "${swap_utilization}" -gt 10; then
        echo "PROBLEM: swap memory usage exceeds threshold"
        rc=69 # EX_UNAVAILABLE
    else
        echo "OK"
    fi
}

if test -r /etc/defaults/periodic.conf; then
    . /etc/defaults/periodic.conf
    source_periodic_confs
fi

case "${minutely_empt_check_swap_usage_enable:-YES}" in
[Yy][Ee][Ss])
    check_swap_usage
    ;;
esac
