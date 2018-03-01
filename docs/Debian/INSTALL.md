# i-MSCP installation on Debian like distributions

## Supported distributions and versions

- Any released Debian version:     ≥ **8/Jessie**
- Any released Devuan version:     ≥ **1.0/Jessie**
- Any released Ubuntu LTS version: ≥ **14.04/Trusty Thar**

## System Requirements

See [System requirements](https://wiki.i-mscp.net/doku.php?id=about:system)

## Installation in an LXC or OpenVZ container

See [LXC containers](https://wiki.i-mscp.net/doku.php?id=about:system#lxc_containers)
See [OpenVZ containers](https://wiki.i-mscp.net/doku.php?id=about:system#openvz_containers_proxmox_and_virtuozzo)

## Installation

### 1 Install the pre-required distribution packages:

```
apt-get --assume-yes --no-install-recommends install ca-certificates perl wget
```

### 1. Download and untar the distribution files

```
cd /usr/local/src
wget https://github.com/i-MSCP/imscp/archive/<version>.tar.gz
tar -xzf <version>.tar.gz
```

### 2. Change to the newly created directory

```
cd imscp-<version>
```

### 3. Install i-MSCP by running its installer

```
perl imscp-installer -d
```

## i-MSCP Upgrade

### 1. Make sure to read the errata file

Before upgrading, you must not forget to read the
[errata file](https://github.com/i-MSCP/imscp/blob/<version>/docs/1.6.x_errata.md)

### 2. Make sure to make a backup of your data

Before any upgrade attempt it is highly recommended to make a backup of the
following directories:

- /var/www/virtual
- /var/mail/virtual

These directories hold the data of your customers and it is really important to
backup them for an easy recovering in case something goes wrong during upgrade

You should also backup all SQL databases.

### 3. Download and untar the distribution files

```
cd /usr/local/src
wget https://github.com/i-MSCP/imscp/archive/<version>.tar.gz
tar -xzf <version>.tar.gz
```

### 4. Change to the newly created directory

```
cd imscp-<version>
```

### 5. Update i-MSCP by running its installer

```
perl imscp-installer -d
```
