i-MSCP listener files
=====================

### Introduction

This directory is meant to hold the listener files which are responsible to
register your own event listeners on the i-MSCP event manager. Any listener
file found in this directory is loaded automatically by i-MSCP at runtime,
in any context.

There is also the **installer** sub-directory that meant to hold listener files
that act in installer context only. It should be useless to load those listener
files outside of the installer context.

### Listener file namespaces

Each listener file must declare its own namespace, inside the iMSCP namespace
such as:

```
iMSCP::Listener::Postfix::Smarthost
```

This allow to not pollute other symbol tables.

### Listener file naming convention

Each listener file must be named using the following naming convention

```
<nn>_<namespace>.pl
```

where

* **nn** is a number which gives the listener file priority
* **namespace** is the lowercase namespace, stripped of the prefix and where
any double colon is replaced by an underscore

In the example above, the filename would be **00_postfix_smarthost.pl**

### Listener file sample (00_sample.pl)

```perl
#!/usr/bin/perl

Package iMSCP::Listener::Sample;

use iMSCP::Debug qw/ warning /;
use iMSCP::EventManager;

# Listener which simply cancel installation
iMSCP::EventManager->getInstance()->register('preBuild', sub {
    warning("Installation has been cancelled by an event listener.");
    exit 0;
});


1;
__END__
```
