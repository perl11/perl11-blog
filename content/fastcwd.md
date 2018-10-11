+++
date = "2018-10-11"
title = "There be getcwd dragons"
tags = [ "cperl", "security" ]
+++

The Cwd perl5 module contains various functions to return the string
of the current working directory.  The POSIX API only contains
`getcwd()`, some provide also `getwd()` - ignored in perl, and the
glibc also provides `get_current_dir_name()` and supports a NULL
argument for `getcwd(char *buf, size_t size)`.  The Cwd module adds
cwd, getcwd, getdcwd for Windows with a drive letter, fastcwd,
fastgetcwd.

# symlinks

The simplify the explanation of the various variants, which in theory
should all return the same string, consider symlinks. If `realpath
"."` expands to something else than your `$PWD`, then the current
directory is behind a symlink. This is a big problem for `rmtree`, as
chdir'ing into a directory which is a symlink would lead to a
situation, where you cannot step out to the previous directory again,
and rmtree would continue deleting something else.  You might chdir
out of a directory that you can't chdir back into.

So to summarize the fastcwd variants, they could return a directory
which contains a symlink, while getcwd should always resolve all
symlinks.  In practice fastcwd should be usable for most cases and
does return the logically correct directory, so users are not surprised
by returning different pathnames for the same directory. But when you
traverse a tree, resolving symlinks should be done to avoid troubles.

cwd() is normally implemented as fastcwd(), just very slow.  E.g. by
shelling out to `pwd`. You really should never use **cwd**, only **fastcwd**
or **getcwd**, depending on your use case.


# long pathnames

On POSIX system the maximal length of a path is specified with
`_POSIX_PATH_MAX` or `PATH_MAX`, which is usually 4096. Older systems
have sometimes limits like 256, newer systems like Windows NT via
certain APIs like 32K. But the actual limitation is really based on
the filesystem, see https://eklitzke.org/path-max-is-tricky.  Many
filesystems do support much longer pathnames than just 4096.  On POSIX
you could use `pathconf` to get the actual limit for this mountpoint,
or you could do it like in cperl: Use the correct API
(`get_current_dir_name`, `getcwd(NULL, 0)`), or check with growing
path buffers until `ENAMETOOLONG` is not returned anymore.

In cperl all the Cwd functions can handle overlong pathnames for some years
already, perl5 cannot.

# security

Attacks on bugs and limitations on pathname API's are quite common and
easy to use. With the right symlink in user space or overlong pathnames
you can trick the system into race attacks. 
See e.g. http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=487319 or 
https://nvd.nist.gov/vuln/detail/CVE-2017-6512 on the File::Path module, which
creates paths and removes trees.

When your system getcwd function does not resolve symlinks, i.e. it is
just fastcwd, rmtree is still vulnerable to symlink attacks. E.g. as
outlined in https://github.com/jkeenan/File-Path/pull/7, which the
maintainer is unwilling to fix.  Also note that the File::Path API
became a mess recently. On yet unsupported arguments, like uid, group
or owner on Windows, the latest version dies, the previous versions
returned an error. As if Windows would not support such metadata. In
fact Windows support much more metadata than traditional POSIX
filesystems, such as ACLs.

This fastcwd problem can e.g. be seen with CPAN, when `~/.cpan/build`
resolves to something else.  Then the `tmp-$$` directory cannot be
deleted, and CPAN aborts.  Or with DBD::File, when your virtual tables
are returned with a "./" prefix when using fastcwd and not getcwd.

But there are so many security problems in perl5, that you really should not
use perl5 in production with public access. Only cperl, which does have those
kind of bugs fixed. And many more.

# Comments on [/r/cperl](https://www.reddit.com/r/cperl/comments/9n86il/there_be_getcwd_dragons/).
