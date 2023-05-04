#!/bin/sh
# Build an iocage jail under TrueNAS 13.0 using the current release of Caddy with Vaultwarden
# git clone https://github.com/tschettervictor/truenas-iocage-vaultwarden

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privileges"
   exit 1
fi

#####
#
# General configuration
#
#####

# Initialize defaults
#JAIL_IP=""
#JAIL_INTERFACES=""
#DEFAULT_GW_IP=""
INTERFACE="vnet0"
VNET="on"
#POOL_PATH=""
#CONFIG_PATH=""
JAIL_NAME="vaultwarden"
#DNS_PLUGIN=""
#CONFIG_NAME="vaultwarden-config"

# Check for vaultwarden-config and set configuration
#SCRIPT=$(readlink -f "$0")
#SCRIPTPATH=$(dirname "${SCRIPT}")
#if ! [ -e "${SCRIPTPATH}"/"${CONFIG_NAME}" ]; then
#  echo "${SCRIPTPATH}/${CONFIG_NAME} must exist."
#  exit 1
#fi
#. "${SCRIPTPATH}"/"${CONFIG_NAME}"
#INCLUDES_PATH="${SCRIPTPATH}"/includes

JAILS_MOUNT=$(zfs get -H -o value mountpoint $(iocage get -p)/iocage)
RELEASE=$(freebsd-version | cut -d - -f -1)"-RELEASE"

# Check that necessary variables were set by vaultwarden-config
#if [ -z "${JAIL_IP}" ]; then
#  echo 'Configuration error: JAIL_IP must be set'
#  exit 1
#fi
#if [ -z "${JAIL_INTERFACES}" ]; then
#  echo 'JAIL_INTERFACES not set, defaulting to: vnet0:bridge0'
JAIL_INTERFACES="vnet0:bridge0"
#fi
#if [ -z "${DEFAULT_GW_IP}" ]; then
#  echo 'Configuration error: DEFAULT_GW_IP must be set'
#  exit 1
#fi
#if [ -z "${POOL_PATH}" ]; then
#  echo 'Configuration error: POOL_PATH must be set'
#  exit 1
#fi
# If CONFIG_PATH wasn't set in vaultwarden-config, set it
#if [ -z "${CONFIG_PATH}" ]; then
#  CONFIG_PATH="${POOL_PATH}"/apps/vaultwarden
#fi

# Extract IP and netmask, sanity check netmask
#IP=$(echo ${JAIL_IP} | cut -f1 -d/)
#NETMASK=$(echo ${JAIL_IP} | cut -f2 -d/)
#if [ "${NETMASK}" = "${IP}" ]
#then
#  NETMASK="24"
#fi
#if [ "${NETMASK}" -lt 8 ] || [ "${NETMASK}" -gt 30 ]
#then
#  NETMASK="24"
#fi

#####
#
# Jail Creation
#
#####

# List packages to be auto-installed after jail creation
cat <<__EOF__ >/tmp/pkg.json
{
  "pkgs": [
  "nano","bash","caddy","vaultwarden"
  ]
}
__EOF__

# Create the jail and install previously listed packages
if ! iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r "${RELEASE}" interfaces="${JAIL_INTERFACES}" ip4_addr="${INTERFACE}|192.168.1.139/23" defaultrouter="192.168.0.253" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}"
then
	echo "Failed to create jail"
	exit 1
fi
rm /tmp/pkg.json

#####
#
# Directory Creation and Mounting
#
#####

#mkdir -p "${CONFIG_PATH}"
mkdir /mnt/RSCPOOL2/apps/vaultwarden

#iocage exec "${JAIL_NAME}" mkdir -p /mnt/includes
#iocage exec "${JAIL_NAME}" mkdir -p /usr/local/www

#iocage fstab -a "${JAIL_NAME}" "/mnt/RSCPOOL2/apps/vaultwarden" /usr/local/www nullfs rw 0 0

#iocage fstab -a "${JAIL_NAME}" "${CONFIG_PATH}" /usr/local/www nullfs rw 0 0
#iocage fstab -a "${JAIL_NAME}" "${INCLUDES_PATH}" /mnt/includes nullfs rw 0 0

#####
#
# Additional Dependency installation
#
#####

# Build xcaddy, use it to build Caddy
#if ! iocage exec "${JAIL_NAME}" "go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest"
#then
#  echo "Failed to install xcaddy, terminating."
#  exit 1
#fi
#iocage exec "${JAIL_NAME}" mv /root/go/bin/xcaddy /usr/local/bin/xcaddy
#if [ -n "${DNS_PLUGIN}" ]; then
#  if ! iocage exec "${JAIL_NAME}" xcaddy build --output /usr/local/bin/caddy --with github.com/caddy-dns/"${DNS_PLUGIN}"
#  then
#    echo "Failed to build Caddy with ${DNS_PLUGIN} plugin, terminating."
#    exit 1
#  fi  
#else
#if ! iocage exec "${JAIL_NAME}" xcaddy build --output /usr/local/bin/caddy
#  then
#    echo "Failed to build Caddy without plugin, terminating."
#    exit 1
#  fi  
#fi

# Copy pre-written config files
#iocage exec "${JAIL_NAME}" cp /mnt/includes/caddy /usr/local/etc/rc.d/
#iocage exec "${JAIL_NAME}" cp /mnt/includes/Caddyfile.example /usr/local/www/
#iocage exec "${JAIL_NAME}" cp -n /mnt/includes/Caddyfile /usr/local/www/ 2>/dev/null

iocage exec "${JAIL_NAME}" sysrc vaultwarden_enable="YES"
iocage exec "${JAIL_NAME}" sysrc caddy_enable="YES"

iocage restart "${JAIL_NAME}"

# Don't need /mnt/includes any more, so unmount it
#iocage fstab -r "${JAIL_NAME}" "${INCLUDES_PATH}" /mnt/includes nullfs rw 0 0
