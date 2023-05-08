# truenas-iocage-vaultwarden
Script to create an iocage jail on TrueNAS with vaultwarden and caddy.

This script will create an iocage jail on TrueNAS CORE 13.0 with the latest release of vaultwarden pkg and caddy pkg. It will configure the jail to store the data outside the jail, so it will not be lost in the event you need to rebuild the jail.

## Status
This script will work with TrueNAS CORE 13.0.  Due to the EOL status of FreeBSD 12.0, it is unlikely to work reliably with earlier releases of FreeNAS.

## Usage

### Prerequisites

You will need to create
- 1 Dataset named `vaultwarden` in your pool.
e.g. `/mnt/mypool/vaultwarden`

If this is not present, a directory `/vaultwarden` will be created in `$POOL_PATH`. You will want to create the dataset, otherwise a directory will just be created. Datasets make it easy to do snapshots etc...

### Installation
Download the repository to a convenient directory on your TrueNAS system by changing to that directory and running `git clone https://github.com/tschettervictor/truenas-iocage-vaultwarden`.  Then change into the new `truenas-iocage-vaultwarden` directory and create a file called `vaultwarden-config` with your favorite text editor.  In its minimal form, it would look like this:
```
JAIL_IP="192.168.1.199"
DEFAULT_GW_IP="192.168.1.1"
POOL_PATH="/mnt/mypool"
HOST_NAME="YOUR_FQDN"
SELFSIGNED_CERT=1
```
Many of the options are self-explanatory, and all should be adjusted to suit your needs, but only a few are mandatory.  The mandatory options are:

* JAIL_IP is the IP address for your jail.  You can optionally add the netmask in CIDR notation (e.g., 192.168.1.199/24).  If not specified, the netmask defaults to 24 bits.  Values of less than 8 bits or more than 30 bits are invalid.
* DEFAULT_GW_IP is the address for your default gateway
* POOL_PATH is the path for your data pool.
* HOST_NAME is the fully-qualified domain name you want to assign to your installation. If you're using a self-signed cert, or not getting a cert at all, it's only important that this hostname resolve to your jail inside your network.
* SELFSIGNED_CERT or NO_CERT. This will determine if a self-signed will be generated (or, in the case of NO_CERT, will run without one. This is the recommended way to run it, behind a reverse proxy. One **and only one** of these must be set to 1.
 
In addition, there are some other options which have sensible defaults, but can be adjusted if needed.  These are:

* JAIL_NAME: The name of the jail, defaults to "vaultwarden"
* INTERFACE: The network interface to use for the jail.  Defaults to `vnet0`.
* JAIL_INTERFACES: Defaults to `vnet0:bridge0`, but you can use this option to select a different network bridge if desired.  This is an advanced option; you're on your own here.
* VNET: Whether to use the iocage virtual network stack.  Defaults to `on`.

Also, HOST_NAME needs to resolve to your jail from **inside** your network.  You'll probably need to configure this on your router, or on whatever other device provides DNS for your LAN.  If you're unable to do so, you can edit the hosts file on your client computers to achieve this result, but consider installing something like [Pi-Hole](https://pi-hole.net/) to give you control over your DNS.

### Execution
Once you've downloaded the script and prepared the configuration file, run this script (`script vaultwarden.log ./vaultwarden-jail.sh`).  The script will run for maybe a minute.  When it finishes, your jail will be created, Vaultwarden will be installed, and you'll be shown the randomly-generated token for the admin portal.

### Notes
The vaultwarden config file is located in `/usr/local/etc/rc.conf.d/vaultwarden` There is also a sample file if you want to review it. the only things different in the one deployed by this script are:
- Signups are allowed by default
- Domain is changed to you $FQDN
SMTP options for vaultwarden and other settings can be changed in the admin portal.

The Caddyfile is located at `/usr/local/etc/caddy/Caddyfile`
