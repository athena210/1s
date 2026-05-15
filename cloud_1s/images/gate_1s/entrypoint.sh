#!/bin/sh -e


iptables -t nat -A POSTROUTING -s "${CLUSTER_NET}" -j MASQUERADE

mkdir -p /etc/dnsmasq
echo "no-resolv" > /etc/dnsmasq/dnsmasq.conf
echo "server=${USE_DNS}" >> /etc/dnsmasq/dnsmasq.conf

echo "Starting supervisor"
exec /usr/bin/supervisord -c /supervisord.conf

echo "==========Container shutdown==============="
exit

# sleep inf
