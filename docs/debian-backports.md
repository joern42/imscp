# Debian backports

With older Debian distribution such as Jessie, it can be interesting to install
the softwares and libraries from the Debian backports repositories whenever as
possible. The problem with the debian backports is that by default, they are
pinned in such a way that you cannot install a package from them without specify
the target to APT.

If you want make use of Debian backports repository with i-MSCP, it is
recommented to override default pinning (100) to a less conservative value
(600):

To do so, you must create an APT preference file as follows

```

```


TODO: Debian installer adapter:

The installer detected that you're using an old Debian distribution. Most of softwares provided by this distribution are outdated. You can improve the situation by installing software from the debian backports repositories which provide more recent versions.

Do you want enable Debian backports? Bear in mind that if you choose yes, the backports repositories will be configured as such that packages from them will be preferred over those from Debian.
