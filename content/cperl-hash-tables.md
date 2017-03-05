+++
date = "2017-03-04"
title = "cperl hash tables"
tags = [ "cperl", "hash" ]
+++

# The old perl5 hash table uses

- linked lists for its collisions, with slow out-of-cache pointer
  chasing and data overhead.

- unsorted flags at the end, while some flags are needed for compare.

- has questionable security measures to slow down all cases. seed ok,
  randomize iter maybe, but randomize the collisions and slow hash
  funcs is stupid. The security should be fixed with proper collision
  iteration, not by pseudo-security theatre upfront.

- no collision search abstraction. The internal implementation quirks
  leaked into core and even external modules.

- four different HE types. Only one is needed.

- inefficient combination of action flags. many magic hash key lookups
  involve internally 3-4 hash lookups.

- was seriously broken 4 times so far.

# In order to clean up the mess, I did the following

* Added multiple new hash functions, run statistics and evaluated them.
  See [perl-hash-stats](https://github.com/rurban/perl-hash-stats)

* Took over maintainance of the general hash function test suite
  [smhasher](https://github.com/rurban/smhasher#smhasher)

* Attempt to fix the wrong wikipedia entry about hash tables. It
  prominently claims that perl5 hash tables are highly optimized, when
  in fact they are highly deoptimized, and are in fact the worst and
  slowest hash table implementation in existance.

* Posted the results to p5p, which was ignored. A few sentences they
  said made it clear, that they had no idea what they were
  doing. E.g. they made fun of Donald Knuth, and of course of me
  *(besides calling me an asshole once again)*. Hinting that they
  maybe should consult an independent expert sitting in the same
  office didn't help. Revising their broken implementation of hash
  tables four times so far doesn't improve trust into their abilities.

* Started implementing perfect hashes, because they were needed to
  speed up all the readonly hashes in core (Config, warnings, unicode
  tables).  Found some interesting new results, esp. how to speed
  up memcmp by [50% - 2000%](http://blogs.perl.org/users/rurban/2014/08/perfect-hashes-and-faster-than-memcmp.html)
  with a constant string.

* Studied hash function and hash table security, and detected a lot of
  theatre and wrong practices in most dynamic languages, but
  interestingly not in the more technical-orientated important public
  services, usually maintained by a single person. Apparently
  community driven development in large teams is the worst,
  contradicting ["The Cathedral and the Bazaar"](http://www.catb.org/esr/writings/cathedral-bazaar/). I'll have to seperate that into a new blog post. There are
  many more tellsigns of community-based development agony.
  Wrote brute-force and solver-based attacks. (*No, I'm not gonna publish
  these*).  So far I could only convince google to revise their
  documentation.  Added hashflood testcases to cperl to test detecting
  such attacks.

# cperl hash tables use

✓ a **fast and short hash function** [FNV1A](https://github.com/rurban/smhasher#smhasher)

✓ proper DoS and DDoS **security** by detecting attacks, logging and
  mitigating it. Not using the slowest of all usable hash function
  SipHash, as this doesn't really help against attacks.

✓ `PERTURB_KEYS_TOP` **move-to-front** with a linked list is the only
  sane strategy for simple chained bucket lists with many reads.

✓ `HV_FILL_RATE`: try lower fill rates than 100%.
  100% is pretty insane, esp. with our bad hash funcs. Make it fast with builtin_ctz.
  [![FNV1A fill rates](https://github.com/rurban/perl-hash-stats/raw/master/hash-fillrate-def-FNV1A.png)](https://github.com/rurban/perl-hash-stats#fill-rates)

✓ use `builtin_ctz` for faster division in `DO_HSPLIT`.
  Allow `-DHV_FILL_RATE=90` definition. (Tested to be the best with `FNV1A`)

✓ extract uncommon magical code in hot code to an extra static
  function to help keep the icache smaller. only in rare cases this
  branch is taken. (i.e filling ENV at startup). Measured 2-15% faster
  with normal scripts, not using tied hashes.

✓ fixed `-DNODEFAULT_SHAREKEYS`, preventing every single hash lookup
  to be done twice.  First in strtab, then in the real hash.

✓ **pre-extend** the hash size to the size of the resulting hashes in many cases
  to avoid initialization splits:
  internal stashes of some known packages, internal hashes of some known size,
  fix the hash assign operator to that in user-code.

and several other minor optimizations. Typically 20% faster than in perl5.

# cperl is working on these improvements:

- abstraction of the abstract **HE_EACH** collision iterator in the
  [feature/gh24-base-hash](https://github.com/perl11/cperl/commits/feature/gh24-base-hash) branch *(stable)*.

- array_he: **abstract AHE**, inline parts of the HE into the
  array. array_he vs ll_he. (linked list, see also the he-array
  branch). array_he (`HvARRAY = AHE[]`) can contain
  `{ hent_he, hent_hash }`. This way the hash catches 99% of all comparisons
  already, and we don't have to chase the external hek ptr, when the
  hash check fails. Every HE entry is then be 2 words (128), instead
  of one word (64), called AHE. The linked list still contains the old
  `HE*`, with `{ hent_next, hent_hek, hent_val }`. This is implemented and
  works fine in the
  [featurex/gh24-hash-loop](https://github.com/perl11/cperl/commits/feature/gh24-hash-loop) branch *(stable)*, and on top of that the [featurex/gh24-array_he](https://github.com/perl11/cperl/commits/feature/gh24-array_he) branch,
  which is the base to most other hash tables below.

- HE\_ARRAY: According to
  http://goanna.cs.rmit.edu.au/~jz/fulltext/spire05.pdf the best for
  chained hashing is currently a **cache-friendly array of buckets**,
  instead of a linked list. cache-friendly continuous buffer of HE's
  w/ inlined HEK (char_) + SV_ val, but no hash, no next ptr. Also for
  shared he's: PL_strtab.

- [small hash type](https://github.com/perl11/cperl/issues/102):
  linear search in embedded array up to 7 keys. ruby, v8 and several
  others measured 3-5 to be a big win, esp. for their object fields,
  but we don't even have that yet. avoid the hash init, calc and search
  overhead, esp. with our overly slow hash tables.

- hash-sortbuckets: a sorted static list of collisions (up to 8, maybe
  start with 3, then 8) as in the Knuth **"ordered hash table"**. We will not
  use that.

- **khash**: use open addressing as everyone else. faster, less space. But
  khash needs a few fixes. And we can not use that, as perl5 is not properly
  abstracted to be able to use external hash tables.

- **one-word-AHE**: As possible improvement on that on 64bit use 48bits
  for the HE ptr, and 16bits of the hash to be compared first. See
  https://www.semanticscholar.org/paper/Fast-Dynamically-Sized-Concurrent-Hash-Table-Barnat-Rockai/ab7dd007587f411cf99bfe056639e055eff22e0c/pdf

- use **robin-hood** as this is currently the best worse-case strategy
  (being super defensive, but not so stupid to use SipHash, which adds
  no benefit). With better native threading support (shared hashes)
  eventually use **leapfrog**.

- **compact ordered hash**. use an array of short indices into a compacted
  array of hash/key/val entries as in PyPy and now python: "compact
  ordered dict". This saves a lot of space and only add's one indirect
  lookup into cache-friendly array. See methane/cpython#1
  https://mail.python.org/pipermail/python-dev/2016-September/146327.html
  This also iterates over the hash in insertion order, which
  effectively hides any attempt to get the seed over the
  iterators. For attacks you need to get collision and robin-hood
  reordering timings.

- get rid of **HEK_WASUTF8**. "There shall be only one state, not
  two". Rather fix the encoding bug (CPAN) instead.

# p5p plans

p5p announced that it is working on switching to an abstract vtable
for hash tables, which is similar to their idea to run-time switch
hash functions truly horrendous.  They say it is needed to abstract
readonly (i.e. perfect hashes), and maybe tied and restricted
hashes.

The cost of this would be another indirection in every hash
table call, and I don't see any benefit.

I don't see a cleanup of the monstrous implementation and different
types and attempts to actually improve any of the problematic issues.
As usual with p5p it will make the situation even worse, not better.

# Conflicts

Having worked with `PERTURB_KEYS_TOP` move-to-front in cperl for a few
years now, there's only one broken module Text::CVS_XS, which assumes
in one of its testcases for parse without headers that the ordering of
keys is stable when the size did not change. The fix is in my
[distroprefs](https://github.com/rurban/distroprefs/blob/master/sources/authors/id/R/RU/RURBAN/patches/Text-CSV_XS-cperl.patch).

Comments on [/r/cperl](http://perl11.org/blog/cperl-hash-tables.html)
