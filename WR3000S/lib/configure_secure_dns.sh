#!/bin/sh

configure_secure_dns() {
    echo "[INFO] Configuring DNS-over-TLS (Quad9 + Cloudflare)..."

    apk add stubby ca-bundle

    mkdir -p /etc/stubby

    cat > /etc/stubby/stubby.yml <<'STUBBY'
resolution_type: GETDNS_RESOLUTION_STUB

dns_transport_list:
  - GETDNS_TRANSPORT_TLS

tls_authentication: GETDNS_AUTHENTICATION_REQUIRED

tls_query_padding_blocksize: 128

edns_client_subnet_private: 1

listen_addresses:
  - 127.0.0.1@5453

round_robin_upstreams: 1

upstream_recursive_servers:
  - address_data: 9.9.9.9
    tls_auth_name: "dns.quad9.net"

  - address_data: 149.112.112.112
    tls_auth_name: "dns.quad9.net"

  - address_data: 1.1.1.1
    tls_auth_name: "cloudflare-dns.com"

  - address_data: 1.0.0.1
    tls_auth_name: "cloudflare-dns.com"
STUBBY

    uci set network.wan.peerdns='0'
    uci -q delete network.wan.dns
    uci add_list network.wan.dns='127.0.0.1'

    uci set dhcp.@dnsmasq[0].noresolv='1'
    uci -q delete dhcp.@dnsmasq[0].server
    uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5453'

    uci commit network
    uci commit dhcp

    /etc/init.d/stubby enable
    /etc/init.d/stubby restart
    /etc/init.d/dnsmasq restart

    echo "[OK] DNS-over-TLS enabled."
}
