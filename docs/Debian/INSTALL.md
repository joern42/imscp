# i-MSCP installation on Debian like distributions

## Officially Supported distributions and versions

- Debian: **8/Jessie**, **9/Stretch**
- Devuan: **1.0/Jessie**, **2.0/ASCII**
- Ubuntu: **14.04/Trusty Thar**, **16.04/Xenial Xerus**, **18.04/Bionic Beaver**

### Regarding Debian and Devuan testing versions

We do not longer support testing versions as long as they are not in freeze
state. Indeed the repositories of a testing version are subject to too many
changes and can break at any time.

### Regarding intermediate (non-LTS) Ubuntu versions

Intermediate (non-LTS) Ubuntu versions should work as well but they are not
officialy supported by our team due to lack of resource. You can always provide
your own distribution package files for them.

## System Requirements

See [System requirements](https://wiki.i-mscp.net/doku.php?id=about:system)

## Installation in an LXC or OpenVZ container

* [LXC containers](https://wiki.i-mscp.net/doku.php?id=about:system#lxc_containers)
* [OpenVZ containers](https://wiki.i-mscp.net/doku.php?id=about:system#openvz_containers_proxmox_and_virtuozzo)

## Installation

### Install the pre-required distribution packages:

```
apt-get --assume-yes --no-install-recommends install screen wget dialog
```

### Download and untar the distribution files

```
cd /usr/local/src
wget https://github.com/i-MSCP/imscp/archive/<version>.tar.gz
tar -xzf <version>.tar.gz
```

### Change to the newly created directory

```
cd imscp-<version>
```

### Run the installer

```
screen -S imscp perl imscp-installer -d
```

## Update

### Backup

Before any update attempt it is highly recommended to make a backup of your
current installation. Assuming the default distribution layout, the following
directories **SHOULD** be backed up:

If you're updating from an i-MSCP version older than 1.5.4:

- /etc/imscp
- /var/mail/virtual
- /var/www/virtual

If you're updating from an i-MSCP version newer than 1.5.3:

- /usr/local/etc/imscp
- /var/mail/imscp
- /var/www/imscp

You **SHOULD** backup all SQL databases as well.

### Errata files

The errata files contain important information regarding changes made
in newest i-MSCP versions. It is important to read them carefully as some manual
tasks could be required before running the installer. If one of a possibly
requirement is not met, the installer could fails unexpectly, leading to a broken
installation.

The latest errata file is available at: [errata file](https://github.com/i-MSCP/imscp/blob/<version>/docs/1.5.x_errata.md)
Don't forget to read the previous errata files if the i-MSCP version you want
to update belongs to an older i-MSCP Serie.

### Download and untar the distribution files

```
cd /usr/local/src
wget https://github.com/i-MSCP/imscp/archive/<version>.tar.gz
tar -xzf <version>.tar.gz
```

### Change to the newly created directory

```
cd imscp-<version>
```

### Run the installer

```
screen -S imscp perl imscp-installer -d
```

## Regarding `SCREEN(1)` window manager usage

In the above documentation, we make use of  `SCREEN(1)` manager to make sure
that the process will continue even if the network connection get interrupted.
This make also us able to support you remotely more easily. With SCREEN(1), one
can switch into the installer session from another terminal as follows:

``` 
screen -x imscp
```

Of course, this is optional.
