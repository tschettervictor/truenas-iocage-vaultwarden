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
JAIL_IP=""
JAIL_INTERFACES=""
DEFAULT_GW_IP=""
INTERFACE="vnet0"
VNET="on"
POOL_PATH=""
CONFIG_PATH=""
JAIL_NAME="vaultwarden"
HOST_NAME=""
SELFSIGNED_CERT=0
NO_CERT=0
CONFIG_NAME="vaultwarden-config"

# Check for vaultwarden-config and set configuration
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "${SCRIPT}")
if ! [ -e "${SCRIPTPATH}"/"${CONFIG_NAME}" ]; then
  echo "${SCRIPTPATH}/${CONFIG_NAME} must exist."
  exit 1
fi
. "${SCRIPTPATH}"/"${CONFIG_NAME}"
INCLUDES_PATH="${SCRIPTPATH}"/includes

ADMIN_TOKEN=$(openssl rand -base64 48)

JAILS_MOUNT=$(zfs get -H -o value mountpoint $(iocage get -p)/iocage)
RELEASE=$(freebsd-version | cut -d - -f -1)"-RELEASE"

# Check that necessary variables were set by vaultwarden-config
if [ -z "${JAIL_IP}" ]; then
  echo 'Configuration error: JAIL_IP must be set'
  exit 1
fi
if [ -z "${JAIL_INTERFACES}" ]; then
  echo 'JAIL_INTERFACES not set, defaulting to: vnet0:bridge0'
JAIL_INTERFACES="vnet0:bridge0"
fi
if [ -z "${DEFAULT_GW_IP}" ]; then
  echo 'Configuration error: DEFAULT_GW_IP must be set'
  exit 1
fi
if [ -z "${POOL_PATH}" ]; then
  echo 'Configuration error: POOL_PATH must be set'
  exit 1
fi

# Check to see certificate options set in config
if [ $NO_CERT -eq 0 ] && [ $SELFSIGNED_CERT -eq 0 ]; then
  echo 'Configuration error: Either NO_CERT,'
  echo 'or SELFSIGNED_CERT must be set to 1.'
  exit 1
fi

if [ $NO_CERT -eq 1 ] && [ $SELFSIGNED_CERT -eq 1 ] ; then
  echo 'Configuration error: Only one of NO_CERT and SELFSIGNED_CERT'
  echo 'may be set to 1.'
  exit 1
fi

# Extract IP and netmask, sanity check netmask
IP=$(echo ${JAIL_IP} | cut -f1 -d/)
NETMASK=$(echo ${JAIL_IP} | cut -f2 -d/)
if [ "${NETMASK}" = "${IP}" ]
then
  NETMASK="24"
fi
if [ "${NETMASK}" -lt 8 ] || [ "${NETMASK}" -gt 30 ]
then
  NETMASK="24"
fi

#####
#
# Jail Creation
#
#####

# List packages to be auto-installed after jail creation
cat <<__EOF__ >/tmp/pkg.json
{
  "pkgs": [
  "nano","bash"
  ]
}
__EOF__

# Create the jail and install previously listed packages
if ! iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r "${RELEASE}" interfaces="${JAIL_INTERFACES}" ip4_addr="${INTERFACE}|${IP}/${NETMASK}" defaultrouter="${DEFAULT_GW_IP}" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}"
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

# Create vaultwarden directory on selected pool
mkdir -p "${POOL_PATH}"/vaultwarden

# Create directory for vaultwarden data inside jail
iocage exec "${JAIL_NAME}" mkdir -p /usr/local/www/vaultwarden

# Mount directory for data inside jail
iocage fstab -a "${JAIL_NAME}" "${POOL_PATH}"/vaultwarden /usr/local/www/vaultwarden nullfs rw 0 0

# Create and mount includes directory for Caddyfile and Vaultwarden file
iocage exec "${JAIL_NAME}" mkdir -p /mnt/includes
iocage fstab -a "${JAIL_NAME}" "${INCLUDES_PATH}" /mnt/includes nullfs rw 0 0

#####
#
# Additional Dependency installation
#
#####

# Install caddy and vaultwarden packages
iocage exec "${JAIL_NAME}" pkg install -y caddy
iocage exec "${JAIL_NAME}" pkg install -y vaultwarden

# Enable caddy and vaultwarden services
iocage exec "${JAIL_NAME}" sysrc vaultwarden_enable="YES"
iocage exec "${JAIL_NAME}" sysrc caddy_enable="YES"

iocage restart "${JAIL_NAME}"

# Generate and insall self-signed cert, if necessary
if [ $SELFSIGNED_CERT -eq 1 ]; then
	iocage exec "${JAIL_NAME}" mkdir -p /usr/local/etc/pki/tls/private
	iocage exec "${JAIL_NAME}" mkdir -p /usr/local/etc/pki/tls/certs
	openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=${HOST_NAME}" -keyout "${INCLUDES_PATH}"/privkey.pem -out "${INCLUDES_PATH}"/fullchain.pem
	iocage exec "${JAIL_NAME}" cp /mnt/includes/privkey.pem /usr/local/etc/pki/tls/private/privkey.pem
	iocage exec "${JAIL_NAME}" cp /mnt/includes/fullchain.pem /usr/local/etc/pki/tls/certs/fullchain.pem
fi

# Copy Caddyfile and vaultwarden config
if [ $NO_CERT -eq 1 ]; then
	echo "Copying Caddyfile for no SSL"
	iocage exec "${JAIL_NAME}" cp -f /mnt/includes/Caddyfile-nossl /usr/local/etc/caddy/Caddyfile 2>/dev/null
elif [ $SELFSIGNED_CERT -eq 1 ]; then
	echo "Copying Caddyfile for self-signed cert"
	iocage exec "${JAIL_NAME}" cp -f /mnt/includes/Caddyfile-selfsigned /usr/local/etc/caddy/Caddyfile 2>/dev/null
fi

iocage exec "${JAIL_NAME}" cp -f /mnt/includes/vaultwarden /usr/local/etc/rc.conf.d/ 2>/dev/null

# Edit Caddyfile and vaultwarden
iocage exec "${JAIL_NAME}" sed -i '' "s/yourhostnamehere/${HOST_NAME}/" /usr/local/etc/caddy/Caddyfile
iocage exec "${JAIL_NAME}" sed -i '' "s/jail_ip/${IP}/" /usr/local/etc/caddy/Caddyfile
iocage exec "${JAIL_NAME}" sed -i '' "s/yourhostnamehere/${HOST_NAME}/" /usr/local/etc/rc.conf.d/vaultwarden
iocage exec "${JAIL_NAME}" sed -i '' "s|youradmintokenhere|${ADMIN_TOKEN}|" /usr/local/etc/rc.conf.d/vaultwarden

# Restart caddy and vaultwarden services
iocage exec "${JAIL_NAME}" service caddy restart
iocage exec "${JAIL_NAME}" service vaultwarden restart


# Don't need /mnt/includes any more, so unmount it
iocage fstab -r "${JAIL_NAME}" "${INCLUDES_PATH}" /mnt/includes nullfs rw 0 0

echo "Installation complete."
echo "Using your web browser, go to https://${HOST_NAME} to log in"

# Save passwords for later reference
echo "Your admin token to access the admin portal is ${ADMIN_TOKEN}" >> /root/${JAIL_NAME}_admin_token.txt
echo "Even if you did a reinstall, the token is different."
