#!/bin/sh
[[ -n "$RACOON_ARGS" ]] || RACOON_ARGS='-F'
[[ -n "$VPN_MY_INTERFACE" ]] || VPN_MY_INTERFACE=eth0

if [[ -z "$VPN_MY_ADDR" ]]; then
	VPN_MY_ADDR_AND_MASK="$(
		ipaddr show "$VPN_MY_INTERFACE" |
		sed -n '/.*inet \([^ ]*\) /{s#.*inet \([^ ]*\).*#\1#;p;q;}'
	)"
	if [[ -z "$VPN_MY_NETWORKS" ]]; then
		case "${VPN_MY_ADDR_AND_MASK#*/}" in
			16)
				VPN_MY_NETWORKS="${VPN_MY_ADDR_AND_MASK%.*.*/16}.0.0/16"
				;;
			24)
				VPN_MY_NETWORKS="${VPN_MY_ADDR_AND_MASK%.*/24}.0/24"
				;;
			*)
				VPN_MY_NETWORKS="${VPN_MY_ADDR_AND_MASK%.*/*}.0/24"
				;;
		esac
	fi
	VPN_MY_ADDR="${VPN_MY_ADDR_AND_MASK%/*}"
fi

if [[ -z "$VPN_MY_NEW_GATEWAY" ]]; then
	VPN_MY_NEW_GATEWAY_ADDR="${VPN_MY_NETWORKS%.*/*}.1"
	VPN_MY_NEW_GATEWAY_MASK="${VPN_MY_NETWORKS#*/}"
	VPN_MY_NEW_GATEWAY="${VPN_MY_NEW_GATEWAY_ADDR}/${VPN_MY_NEW_GATEWAY_MASK}"
fi

if
	[[ -n "$VPN_TUNNEL_ADDR" ]] &&
	[[ -f /vpn-psk ]]
then
	printf '%s %s\n' "$VPN_TUNNEL_ADDR" "$(cat /vpn-psk)" > /etc/conf.d/psk.txt
fi

if
	[[ -n "$VPN_TUNNEL_ADDR" ]] &&
	[[ -n "$VPN_MY_NETWORKS" ]]
then
	cat > /etc/conf.d/racoon <<-CONF
		path pre_shared_key "/etc/racoon/psk.txt";
		remote $VPN_TUNNEL_ADDR {
			exchange_mode main,aggressive;
			nat_traversal force;
			my_identifier address $VPN_MY_ADDR;
			proposal {
				authentication_method pre_shared_key;
				hash_algorithm sha1;
				encryption_algorithm aes 128;
				lifetime time 28800 seconds;
				dh_group 2;
			}
		}
		sainfo address $VPN_MY_NETWORKS any address $VPN_TUNNEL_NETWORKS any {
			authentication_algorithm hmac_sha1;
			encryption_algorithm aes 128;
			lifetime time 3600 seconds;
			pfs_group 2;
			compression_algorithm deflate;
		}
	CONF
fi

if
	[[ -n "$VPN_TUNNEL_ADDR" ]] &&
	[[ -n "$VPN_TUNNEL_NETWORKS" ]] &&
	[[ -n "$VPN_MY_ADDR" ]] &&
	[[ -n "$VPN_MY_NETWORKS" ]]
then
	cat > /etc/ipsec-tools.conf <<-CONF
		#!/usr/sbin/setkey -f
		flush;
		spdflush;
		spdadd $VPN_MY_NETWORKS $VPN_TUNNEL_NETWORKS any -P out ipsec esp/tunnel/$VPN_MY_ADDR-$VPN_TUNNEL_ADDR/require;
		spdadd $VPN_TUNNEL_NETWORKS $VPN_MY_NETWORKS any -P in ipsec esp/tunnel/$VPN_TUNNEL_ADDR-$VPN_MY_ADDR/require;
	CONF
fi

ipaddr add "${VPN_MY_NEW_GATEWAY}" dev "${VPN_MY_INTERFACE}"
ip route add to $VPN_TUNNEL_NETWORKS via "${VPN_MY_NEW_GATEWAY%/*}" src "${VPN_MY_NEW_GATEWAY%/*}"

/usr/sbin/setkey -f /etc/ipsec-tools.conf
/usr/sbin/racoon $RACOON_ARGS -f /etc/conf.d/racoon
