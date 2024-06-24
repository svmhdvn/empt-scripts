#!/bin/sh
set -eu

# TODO monitoring tasks
# * check memory usage
# * check zpool health
# * warn on zpool space usage >= 75%
# * check TLS cert expiry
# * check S.M.A.R.T. status on storage drives
# * check IMAP and SMTP availability
# * check IRC availability
# * ensure swap usage is low
# * monitor the uptime in some way if possible, ensure no reboots

/usr/local/libexec/nagios/check_load -r -w 0.90 -c 0.95
