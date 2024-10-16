#!/bin/sh

validate_tls_certs() {
    rc=0
    echo "===== EMPT: validate TLS certs on open ports ====="

    # TODO finish
    # NOTE auth_level=3 disallows public keys < 256 bits
    # auth_level=4 seems optimal, but not sure about performance
    # suiteB_128_only forces ECC P-256
#    tls_services="mail.home.arpa 465
#mail.home.arpa 993
#irc.home.arpa 443
#irc.home.arpa 6697"
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
                echo "TLS cert for '${host}:${port}' is OK"
            else
                echo "PROBLEM: TLS cert for '${host}:${port}' expires soon"
                rc=69 # EX_UNAVAILABLE
            fi
        else
            echo "PROBLEM: TLS cert for '${host}:${port}' is invalid"
            rc=69 # EX_UNAVAILABLE
        fi
    done <<EOF
${daily_empt_validate_tls_certs_services}
EOF
    exit "${rc}"
}

if test -r /etc/defaults/periodic.conf; then
    . /etc/defaults/periodic.conf
    source_periodic_confs
fi

case "${daily_empt_validate_tls_certs_enable:-NO}" in
    [Yy][Ee][Ss]) validate_tls_certs ;;
    *) ;;
esac
