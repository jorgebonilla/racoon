# Minimal VPN Tunnel Appliance
Connects to a VPN Tunnel using Racoon on Alpine Linux

This has not been vetted for production use, and exists to test AWS
VPN configurations prior to the installation of long-term solutions.

Theoretically, this could be used with other (non-AWS) ipsec tunnels,
but only ipsec gateways on AWS have been tested.

## Basic Usage
```bash
docker run \
    -e VPN_TUNNEL_NETWORKS=<netmask of private VPC subnet, eg: 10.0.0.0/16> \
    -e VPN_TUNNEL_ADDR=<public routable address of the AWS VPN Connection Tunnel> \
    -v <a file containing only the Pre-Shared Key of the VPN Tunnel>:/vpn-psk \
    --cap-add=NET_ADMIN \
    -d jorgebonilla/racoon
```

You may either use `docker exec` to run processes within the tunnel, or tell
your host (or other containers) to route connections to the private VPC subnet
through the container.

Example routing rule:
```bash
sudo route add -net 10.0.0.0 netmask 255.255.0.0 gw 172.17.0.7 dev docker0
```

note: you *may* need to `modprobe esp4` to ensure that the ipsec tunnels used by
racoon are supported by your kernel.

## Environment Variables
```
VPN_TUNNEL_NETWORKS=<netmask of private VPC subnet, eg: 10.0.0.0/16>
VPN_TUNNEL_ADDR=<public routable address of the AWS VPN Connection Tunnel>
VPN_MY_ADDR=<ip address of private Docker container, eg: 172.17.0.7>
VPN_MY_NETWORKS=<netmask of private Docker subnet, eg: 172.17.0.0/16>
VPN_MY_INTERFACE=<name of device to attach to, eg: eth0>
RACOON_ARGS=<arguments to pass to racoon, eg: -F>
```
