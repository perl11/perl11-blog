+++
date = "2017-04-27"
title = "Automatic cperl deployments"
tags = [ "cperl" ]
+++

# Binary packages

perl5 relies on external packagers to update and maintain packages for
various distributions. It only provides source packages as tarballs.

cperl does a bit better by also providing binary packages for all
major platforms. See also **Installation** at the 
[STATUS](https://perl11.github.io/cperl/STATUS.html) page.
[win32, win64](https://perl11.github.io/win/), debian 7 i686, debian 8 amd64,
centos 7 x86\_64, centos 6 i686+x86_64 and [darwin amd64](https://perl11.github.io/osx/).

Packaging was done with this [do-make-cperl-release](https://github.com/perl11/cperl/blob/master/Porting/do-make-cperl-release) script, leading to

Centos/Fedora/RHEL as el6 or el7 `/etc/yum.repos.d/perl11.repo`:

    [perl11]
    name=perl11
    baseurl=https://perl11.github.io/rpm/el7/$basearch
    enabled=1
    gpgkey=https://perl11.github.io/rpm/RPM-GPG-KEY-rurban
    gpgcheck=1

or for Debian/Ubuntu `/etc/apt/sources.list.d/perl11.list`:

    deb https://perl11.github.io/deb/ sid main

So far the packaging was done on private build VM's, and the hosting
was done on github.  Yes, you can easily host deb and rpm distros for
free at github pages.  But the idea is also to use external package
providers, like [OpenSUSE OBS](https://build.opensuse.org/)
or [Bintray](https://bintray.com/perl11/), which do packaging and
hosting for many more platforms.

# Autodeploy

With cperl-5.26.0c the packaging for at least win32 and the new win64
platforms with MSVC12 and darwin is done automatically via tagging a release and pushing it
to [github](https://github.com/perl11/cperl/releases).
For MSVC12 you'll need the _msvcr120.dll_ runtime,
available e.g. from the Microsoft VS 2013 C++ Redistributable Package
from https://www.microsoft.com/en-us/download/details.aspx?id=40784

Since [today](https://github.com/perl11/cperl/commit/9a79df78a29fb50a3c2837cdd2a8422fe98b760a) appveyor provides the windows deployments, and [travis](https://travis-ci.org/perl11/cperl/builds) the linux src tarballs and darwin deployments.

Additionally [appveyor](https://ci.appveyor.com/project/rurban/cperl/history)
provides also nightly builds on every master change. This is for now
only in private draft releases, but I'll think about enabling it as
pre-releases.

Travis does not support nightly builds as easy as Appveyor.
With Appveyor you can tag your deployments as

    draft: true
    prerelease: true
    force_update: true

but with Travis you can only deploy tags. So for a nightly you would need to add a
tag for every master change, there's no deploy condition:

    on:
      appveyor_repo_tag: true

vs.

    on:
      branch: /(master|relprep)/

The missing `prerelease` or `draft` tag on Travis also means that
every deployment on tags is a proper release, and you have to manually
change that to a *Pre-Release* on the github release page. You cannot
change that to an invisible *Draft* release.

The Appveyor `force_update: true` deploy tag means that you can start
a deployment from win32/msvc12 and add files from e.g. win64 later to
that github release. Travis always allows that. E.g. the src tarballs
are added first and darwin pkgbuild files are added later.

One could also think of extending that to CPAN uploads, by encrypting the PAUSE key
and let Travis-CI trigger the cpan upload on every new release tag.
