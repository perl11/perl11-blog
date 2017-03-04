+++
date = "2017-01-30"
title = "Worst perl5 bugs"
tags = [ "perl5", "cperl" ]
+++

# A small list of the worst perl5 bugs, all fixed in cperl

# DoS

It's trivial to DoS a perl5 system.

    $a[9223372036854]=0;
    %a=(0..4294967296);

Examples for a 64bit system, but also trivial on 32bit.
It creates a huge array or hash, which runs out of memory in the VMM
subsystem which eventually kills the process.
cperl dies with "Too many elements", here even at compile-time.

# No Hash Security

Nothing is done against the root-cause of a hash flood denial of
service attack with colliding keys, only some security theatre by
using slower hash functions and slower collision resolution
`KEY_PERTURB_RANDOM`.  If the seed is exposed, trivially on perl5 as
it is at a fixed known address offset readable via unpack, or exposed
via the command line, there is no prevention. Only cperl is secure,
and also much faster.  See e.g. [cperl `t/op/hashflood.t`](https://github.com/perl11/cperl/blob/master/t/op/hashflood.t)
Or [perl5241cdelta/"Protect and warn on hash flood DoS"](http://perl11.org/cperl/perl5241cdelta.html#Protect-and-warn-on-hash-flood-DoS).

    PERL_HASH_SEED_DEBUG=1 perl -e1

Pointing that out on p5p led to the developer simply ignoring it. Instead they
are working on making it even slower, but not improving the horrible implementation
and security.

# Language Maintainance

## Silent integer overwraps

    @a=(0,1); print $a[~1] => 0

`~1` is essentially `(UV)-2` or `0xffff_fffe`.

    @a=(1);print $a[18446744073709551615]' => 1

Silent overwrap of 18446744073709551615 to -1.

The same happens with overlong hash keys, they are not converted to
SVs which can hold overlong strings. Everything in the buffer after
I32 s ignored.  Or with overlong hashes, where you can create huge hashes
>I32 but can only iterate over the first I32 entries.

With cperl the "Too many elements" error is now triggered when
accessing or extending an out of bounds array index or trying to
insert too many hash keys. This is to prevent from silent hash or
array overflows. Previously extending a hash beyond it's capable size
was silently ignored, leading to performance degradation with overly
high fill factors and extending an array failed only on memory
exhaustion, but the signed index led to an index overflow between I32
and U32, resp.  I64 and U64.

Even worse, accessing overflown unsigned array indices would silently
access the signed counterpart, indices at the end.

chop/chomp only works on half of overlarge arrays.

Or ~"a"x2G complement of overlarge strings, silently processing only
the half - as with overlong hash keys.

There was also a smartmatch Array - CodeRef rule, which passed only over
half the array elements.  The Hash part was also wrong, but the wrong number
was not used.

regex match group of >2GB string len.

repeat count >2GB and don't silently cap it at IV_MAX. Which was
at least better then silent wrap around.

# Names

## Binary names

Only cperl is binary safe against \0 in names, which is esp. unsafe with
package names, being mapped 1:1 to filenames.

## Insecure unicode names

Unicode allows to be identifiers not identifiable, i.e. confusable
evading visual inspection of 3rd party code. Bidi spoofs can contain
right-to-left overwriting L-T-R characters, combining marks, mixed
scripts (e.g. Cyrillic and Greek), ...

There's a TR39 security guideline for identifiers which [cperl implements](http://perl11.org/cperl/perl5252cdelta.html#Security).
perl5 has no idea about that and is not willing to fix it, even if perlcc
prominently warns about that since 5.16.

No [Unicode confusables +UFFA0, +U3164](http://perl11.org/cperl/perl5240cdelta.html#Security). In deviation from Unicode 1.1
we treat the two HANGUL FILLER characters +UFFA0 and +U3164 not as
valid ID\_Start and ID\_Continue characters for perl identifiers.

## overlong names

The "panic: hash key too long" error is now thrown with overlarge hash keys in every
`hv_common` access and in Cpanel::JSON::XS.
perl5 still silently ignores those failures, and truncates the keys.

Many more similar "panic: (file|keyword|mro|stash)? name too long" errors
were added to the parser and compiler to protect from overlong names
(> I32_MAX, 2147483647).

## Insecure taint mode

perl5 has several known taint loopholes, see [perlsec](http://perl11.org/cperl/perlsec.html#Taint-mode). cperl has them all fixed.

Of course it is much faster to use tainted variables, as you don't have to
check and sanitize every single variable, only external, tainted ones.

# Minor issues from [perl540cdelta](http://perl11.org/cperl/perl5240cdelta.html#Security)

## DynaLoader format string hardening

Replace all `%` characters in user-controlled library filenames, passed via
the system dl_error call verbatim to `printf`, without any arguments on the stack,
which could lead to execution of arbitrary stack code. No CVE.
This affects all systems with dynamic loading where the attacker can cause a
dynamic loading error.

CVSSv2 Severity: 7.2
(AV:L/AC:L/Au:N/C:C/I:C/A:C/E:U/RL:OF/RC:C/CDP:MH/TD:H/CR:H/IR:H/AR:ND)


## XSLoader relative paths with eval or #line

Upstream XSLoader 0.22 (perl 5.26) fixed a minor security problem with
XSLoader within eval or with a #line directive, which can load a local
relative shared library, which is not in `@INC`.
See https://rt.cpan.org/Ticket/Display.html?id=115808

cperl XSLoader was already protected against the eval case since 5.22,
when being rewritten in C. cperl-5.24.0 fixed now also ignoring a relative
filename in a `#line` directive, when the relative path is not in `@INC`.

## handle method calls on protected stashes

https://github.com/perl11/cperl/issues/171

Known bug upstream, not fixed there. This problem appears more often
with cperl with its protected coretypes than upstream.


## fedora: Do not crash when inserting a non-stash into a stash

[Fedora Patch 37 RT#128238](https://rt.perl.org/Public/Bug/Display.html?id=128238)

## fedora: Do not treat %: as a stash

[Fedora Patch36 RT#128238](https://rt.perl.org/Public/Bug/Display.html?id=128238)

## fedora: Fix precedence in hv_ename_delete

[Fedora Patch35 RT#128086](https://rt.perl.org/Public/Bug/Display.html?id=128086)


## fedora: Do not use unitialized memory in $h{\const} warnings

[Fedora Patch34 RT#128189](https://rt.perl.org/Public/Bug/Display.html?id=128189)

## fedora: Do not mangle errno from failed socket calls

[Fedora Patch32 RT#128316](https://rt.perl.org/Public/Bug/Display.html?id=128316)


## fedora: Backport memory leak when compiling a regular expression with a POSIX class

E.g. when C<use re 'strict';> is used.

[Fedora Patch31 RT#128313](https://rt.perl.org/Public/Bug/Display.html?id=128313)

## suse: perl5.24.0.dif

Many Configure and linux hints enhancements, esp for lib64,
probe fixes, gdbm and ODBM fixes, gnu readline integration with the debugger.
See https://build.opensuse.org/package/show/devel:languages:perl/perl

## suse: fix regexp backref overflows

With many backref groups (>I32)

## suse: perl-saverecontext.diff RT#76538

Handle get magic with globs in the regex compiler.
Correctly restore context, esp. when loading unicode swashes.
Reported at 5.12, patched for suse 5.14, still ignored with 5.24.

# Minor issues from [perl541cdelta](http://perl11.org/cperl/perl5241cdelta.html#Security)

## Warn on metasploit CVE-2015-1592

Detection of the destructive attack against Movable-Type, the third
vector only, which tries to delete `mt-config.cgi` was added to was
added to cperl `Storable` 3.01c.

Warns with "SECURITY: Movable-Type CVE-2015-1592 Storable metasploit attack"
but does not protect against it.

## Warn on metasploit reverse shells

Detect the metasploit payload unix/reverse_perl and some existing
variants.  This is just a dumb match at startup against existing
exploits in the wild, but not future variants.  Warns with
"SECURITY: metasploit reverse/bind shell payload", but do not
protect against it. This warning is thrown even without C<-w>.

Also detects the CVE-2012-1823 reverse/bind shell payload, which is
widely exploited too. The security warning is called
"SECURITY: CVE-2012-1823 reverse/bind shell payload".

## Fixed overwriting the HVhek_UNSHARED bit in the hash loop

Broken with v5.9

This fixed `-DNODEFAULT_SHAREKEYS`. In the default configuration
without `NODEFAULT_SHAREKEYS` since 5.003_001 all hash keys are stored
twice, once in the hash and once again in `PL_strtab`, the global
string table, with the benefit of faster hash loops and copies. Almost
all hashtables get the SHAREKEYS bit.

With `-Accflags=-DNODEFAULT_SHAREKEYS` simple scripts are 20-30%
faster.  https://github.com/perl11/cperl/issues/201 but practical
usage is dominated by copying hashes, which is faster with shared
keys.

## -Dfortify_inc

Was in the very first cperl release 5.22.1. With full toolchain
support, in all modules. perl5 caught up 2 years later, 5.26.
But of course they changed the established name to their own
`-Ddefault_inc_excludes_dot`

## perl4 ' package seperator

cperl deleted that, and fixed all issues.

# unicode bugs

e.g range is broken in perl5, fixed in cperl 5.24.1c.
Apparently fixed with 5.26 finally.

    my $r = chr 255; utf8::upgrade $r; my $num = ("a" .. $r);

## utf8 padnames

In perl5 all padnames are utf8 encoded by default. In cperl only those
who are utf8 encoded. https://github.com/perl11/cperl/issues/208

## compiler toolchain support

perl5 links with CC and ignores the linker LD, which disables advanced
llvm thin, lto and cfe support. e.g. clang-4 is produces 20% faster
code, and with cfe much safer code.

perl5 is inable to produce reproducible builds. cperl does it by default.

## lexical $_ support

perl5 was not able to find and fix the trivial bugs.
Their core features and modules rely on that, but they removed it.
esp. given/when, smartmatch, List::Utils.
cperl supports it.

## use encoding

perl5 was not able to find and fix the trivial bugs. Many foreign devs
rely on that, but they removed it.  cperl supports it.

## PL_maxo

perl5 removed it, while it is necessary to track custom ops.
cperl supports it.

## for qw(...)

perl5 removed support `for qw()` with bogus justification. You need to write
`for (qw(..)) {}`
The promised parser improvements never arrived.

cperl allows `for qw(...)` and supporting it is trivial.

## .pmc loading and reflection

perl5 removed timestamp checks for pugs with 5.8, a module doesn't
know if it's loaded from a .pmc, and force loading a .pm is not
possible.

cperl fixed that for the upcoming JitCache support, which adds
expensively optimized subs for a package to a .pmc. But only some, not
all subs.  So a .pmc can never replace a full .pm. So reflection and
loading .pm needs to be enabled.

# Core modules

## Storable

The CPAN version was never updated.  The core version suffers from
several severe core bugs, similar to the inability in core to support
huge >2GB data.

cperl Storable fixes JD's stack-overflow write (totally a CVE),
detects the known MetaSploit attack vector and supports large objects,
strings, hashed and arrays.

There are also more stack-overflow attacks fixed in my CPAN version.

## YAML

YAML is slow, incompatible with itself and insecure by default.

e.g. Parse-CPAN-Meta security: cperl is 10x faster, can read its own files
and sets $YAML::XS::DisableCode, $YAML::XS::DisableBlessed while
parsing META.yml or CPAN .yml files.

Very similar to Storable. At least with YAML the upstream maintainer is listening,
but he needs >1 year to merge my fixes, which is not acceptable. Nothing published 
yet upstream. Needs to be forked to Cpanel::YAML::XS eventually.

## JSON::XS

Look at the relevant pod section in [Cpanel::JSON::XS](http://search.cpan.org/dist/Cpanel-JSON-XS/XS.pm#SECURITY_CONSIDERATIONS)

# Summary

For the security bugs see on cperl:

    grep -A20 '=head1 Security' pod/perl*cdelta.pod

