# i-MSCP installation on Debian like distributions

## Supported distributions and versions

- Debian: **8/Jessie**, **9/Stretch**, **10/Buster (experimental)**
- Devuan: **1.0/Jessie**
- Ubuntu: **14.04/Trusty Thar**, **16.04/Xenial Xerus**, **18.04/Bionic Beaver**

## System Requirements

See [System requirements](https://wiki.i-mscp.net/doku.php?id=about:system)

## Installation in an LXC or OpenVZ container

See [LXC containers](https://wiki.i-mscp.net/doku.php?id=about:system#lxc_containers)
See [OpenVZ containers](https://wiki.i-mscp.net/doku.php?id=about:system#openvz_containers_proxmox_and_virtuozzo)

## Installation

### 1 Install the pre-required distribution packages:

```
apt-get --assume-yes --no-install-recommends install ca-certificates perl screen wget
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
screen -S imscp perl imscp-installer -d
```

Note that we make use of  `SCREEN(1)` to make sure that the process will
continue even if the network connection is interrupted. This allows us to
re-switch into the session as follows:

``` 
screen -x imscp
```

## i-MSCP Upgrade

### 1. Make sure to read the errata file

Before upgrading, you must not forget to read the
[errata file](https://github.com/i-MSCP/imscp/blob/<version>/docs/1.6.x_errata.md)

### 2. Make sure to make a backup of your data

Before any upgrade attempt it is highly recommended to make a backup of the
following directories:

- /etc/imscp
- /var/www/virtual
- /var/mail/virtual

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
screen -S imscp perl imscp-installer -d
```

Note that we make use of  `SCREEN(1)` to make sure that the process will
continue even if the network connection is interrupted. This allows us to
re-switch into the session as follows:

``` 
screen -x imscp
```
