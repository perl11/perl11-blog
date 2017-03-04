+++
date = "2016-11-26T12:35:00+02:00"
title = "The dangerous SipHash myth"
tags = [ "hash", "security" ]
+++

SipHash claims that its "cryptographically strong pseudo random
function" properties protects against hash table DoS flood attacks.
This is wrong, because for a successful attack against a SipHash hash
table with chained linked lists or linear probing it is enough to get
the secret random seed, and then brute force create collisions, which
is doable in <1s for 16k keys, 2m for 16k keys, and from 32k to 268M
keys in 4 minutes. For any hash function, SipHash, AES or even SHA256.
Which is far from being secure. Declaring a hash function for a hash
table secure is wrong and pure security theatre, which unfortunately
a lot of people started to believe in.

Normally you can prepare collisions offline, but as you see you can
even create them online as soon as you know the seed.  Inserting 64k
keys needs 32 seconds vs 0.01 seconds on e.g. PHP, from constant to
quadratic, with an amplification factor of 200.
https://events.ccc.de/congress/2011/Fahrplan/events/4680.en.html

So the only protection is the secrecy of the random seed, which has
nothing to do with any properties of SipHash per se. A hash
function can never protect a hash table from hash flood attacks on
hash tables with simple lists on collisions. SipHash properties are
that is not reversible, the seed is mixed in the box and not only
at the beginning, so it's is hard to get the seed from the hash
function itself. But there's no need for it, as it is trivial to
get the seed via other means. The collisions are prone to timing
attacks independent on the hash function, usually the hash
iterator exposes the inner ordering and in most cases the random
seed is exposable via traditional memory exposure. If the seed is
hash table specific or global, i.e. process or thread specific.

E.g. in debian perl you get the seed at process startup via


    $ PERL_HASH_SEED_DEBUG=1 /usr/bin/perl -e0
    => HASH_FUNCTION = ONE_AT_A_TIME_HARD HASH_SEED = 0xd12d459fc36db4cf PERTURB_KEYS = 1 (RANDOM)

to stderr.

On centos7:

    $ PERL_HASH_SEED_DEBUG=1 /usr/bin/perl -e0
    => HASH_SEED = 10452142639498245987

Older centos 5 and 6 has an unpatched perl hash table function which
is vulnerable to much simplier DoS attacks, which is e.g. used on the
redhat openshift public cloud.

For a running perl process the seed is at a known fixed offset.  Which
is easily readable via some kind of poke function via the unpack "P"
builtin op. See Devel::PeekPoke.  Similar for all other dynamic
languages exposing the value of any pointer. Which is esp. problematic
for languages who trusted the false claims of the SipHash authors,
that using this secure hash function it makes it safe against such DoS
attacks. Which are most prominently ruby, python, rust, haskell and
others.  Perl5 at least changed the order of the iterator, cperl
counts the collisions and adds a sleep on attacks, PHP limits the size
of external keys to be passed to the hash table so only JSON or other
formats are easily DoS-able. But more serious applications such as the
linux kernel, glibc, cache or DNS servers use better hash table
collisions schemes than unsafe chaining or linear probing.

Vulnerable are all implementors of hash tables who believed the false
claims of the SipHash authors: ruby, python, rust, haskell, OpenBSD
and some more.  But also others who don't use a proper hash table
collision resolution scheme or don't protect their seed or easily
expose the seed, such as perl5 and many more.  rust currently
e.g. believes that SipHash makes it secure even if a trivial attack
was just found against it, and changing the seed at table resize will
help. It only helps a bit.  The seed is still exposable.  With an
amplification factor of 200 with a table size large enough there's
enough attack surface to render a service useless.
Reseeding on resize will lead to an amplification factor of 6.

Links:

* [google/highwayshash False security claims](https://github.com/google/highwayhash/issues/28)
* [SMHasher on Security](https://github.com/rurban/smhasher/#security)
* [perl hash stats](https://github.com/rurban/perl-hash-stats)

