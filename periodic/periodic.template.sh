#!/bin/sh

do_the_thing() {

}

if test -r /etc/defaults/periodic.conf; then
    . /etc/defaults/periodic.conf
    source_periodic_confs
fi

rc=0

case "${PERIOD_SCRIPTNAME_enable:-NO}" in
[Yy][Ee][Ss])
    do_the_thing
    ;;
esac

exit "${rc}"
