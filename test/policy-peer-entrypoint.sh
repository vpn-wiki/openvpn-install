#!/bin/bash
set -e

WAIT_TIMEOUT="${WAIT_TIMEOUT:-120}"
elapsed=0

while [ ! -f /shared/policy-peer.ovpn ]; do
	if [ "$elapsed" -ge "$WAIT_TIMEOUT" ]; then
		echo "FAIL: Timed out waiting for peer client configuration"
		exit 1
	fi
	echo "Waiting for peer client configuration... (${elapsed}/${WAIT_TIMEOUT}s)"
	sleep 2
	elapsed=$((elapsed + 2))
done

openvpn --config /shared/policy-peer.ovpn --daemon --log /var/log/openvpn-policy-peer.log

elapsed=0
until ip -4 addr show tun0 2>/dev/null | grep -q 'inet '; do
	if [ "$elapsed" -ge "$WAIT_TIMEOUT" ]; then
		echo "FAIL: Timed out waiting for peer VPN connection"
		cat /var/log/openvpn-policy-peer.log 2>/dev/null || true
		exit 1
	fi
	echo "Waiting for peer VPN connection... (${elapsed}/${WAIT_TIMEOUT}s)"
	sleep 2
	elapsed=$((elapsed + 2))
done

PEER_IP=$(ip -4 -o addr show tun0 | awk '{print $4}' | cut -d/ -f1)
printf '%s\n' "$PEER_IP" >/shared/policy-peer-ip
echo "Policy peer connected with VPN address $PEER_IP"

exec tail -f /var/log/openvpn-policy-peer.log
