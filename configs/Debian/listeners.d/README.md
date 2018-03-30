i-MSCP listener files
=====================

### Introduction

Listeners files are simple Perl scripts which are automatically loaded by the
i-MSCP event manager at runtime. These listener files make it possible to hook
into i-MSCP by registering event listeners which listen events that are
triggered by various i-MSCP components.

There are a lot of events triggered, in different contexts. Unfortunately,
there is not documentation yet for them but that will be fixed soon. At the
time being, you still need read the code to find and understand them...

There are already several listener files available, for various usages. Those
are maintained by the i-MSCP team and provided with each release into the
contrib directory of the distribution archive. Most of listener files were
provided AS THIS by the i-MSCP community but those are generally reviewed by
our own team on each release.

When a new i-MSCP version is released, and prior any update attempt, you must
not forget to grab latest versions of the listener files to update your own.
By not doing so, you could end with a broken i-MSCP installation as there is
no compatibility garanti for older versions of listener files.

#### Usage

One of the best use of the listener files is when you want re-inject your own
changes automatically in the service configuration files such as Postfix,
Bind9, Apache2... Indeed, for safety and simplicity reasons, i-MSCP always
regenerate the various configuration files from scratch when an update or
reconfiguration is triggered.

Another use is when you want connect a 3rd-party service, or anything else to
i-MSCP without having to develop a full i-MSCP plugin.

### Installation

This directory is meant to hold the listener files which are responsible to
register your own event listeners on the i-MSCP event manager. Any file found
in this directory is loaded automatically by i-MSCP at runtime, in all
contexts.

There is also the **installer** sub-directory. That directory meant to hold
listener files that act in installer context only. It is best avoided to load
those listener files in context other than installer as this would involve
useless performance penality, even though, registration of event listeners is
relatively cheap.

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
