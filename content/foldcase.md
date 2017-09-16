+++
date = "2017-09-16"
title = "The sad state of foldcase and string comparisons"
tags = [ "cperl", "unicode" ]
+++

You probably heard about case-folding or **foldcase** before.
Unicode defines CaseFolding mappings for some upper-case characters,
which in full casefolding mode will expand some exotic characters
to larger sequences. In simple mode it will do 1:1 `tolower()` mappings.

------

The **perl** documentation has this to say:

**fc**
------

*Returns the casefolded version of EXPR. This is the internal function
implementing the "\F" escape in double-quoted strings.*

*Casefolding is the process of mapping strings to a form where case
differences are erased; comparing two strings in their casefolded form
is effectively a way of asking if two strings are equal, regardless of
case.*

*Roughly, if you ever found yourself writing this*

    lc($this) eq lc($that)    # Wrong!
        # or
    uc($this) eq uc($that)    # Also wrong!
        # or
    $this =~ /^\Q$that\E\z/i  # Right!

*Now you can write*

    fc($this) eq fc($that)

*And get the correct results.*

So far there is no bug and everything is fine.

------

**Unicode** has this say:

http://www.unicode.org/reports/tr44/#Casemapping

*Case for bicameral scripts and case mapping of characters are
complicated topics in the Unicode Standard—both because of their
inherent algorithmic complexity and because of the number of
characters and special edge cases involved.*

*This section provides a brief roadmap to discussions about these
topics, and specifications and definitions in the standard, as well as
explaining which case-related properties are defined in the UCD.*

http://unicode.org/reports/tr21/tr21-5.html#Caseless_Matching

*The [CaseFolding](http://www.unicode.org/reports/tr44/tr44-20.html#Casemapping) file
in the Unicode Character Database is used for performing
locale-independent case-folding. This file is generated from the case
mappings in the Unicode Character Database, using both the
single-character mappings and the multi-character mappings. It folds
all characters having different case forms together into a common
form. To compare two strings for caseless matching, you can fold each
string using this data, and then use a binary comparison.*

*Generally, where case distinctions are not important, other distinctions between Unicode characters (in particular, compatibility distinctions) are ignored as well. In such circumstances, text can be normalized to Normalization Form KC or KD after case-folding, to produce a normalized form that erases both compatibility distinctions and case distinctions. (See UTR #15: Unicode Normalization Forms for more information.) However, such normalization should generally only be done on a restricted repertoire, such as identifiers (alphanumerics).*

------

**w3.org** gets closer to the real problem:

https://www.w3.org/International/wiki/Case_folding

*One of the most common things that software developers do is "normalize" text for the purposes of comparison. And one of the most basic ways that developers are taught to normalize text for comparison is to compare it in a "case insensitive" fashion. In other cases, developers want to compare strings in a case sensitive manner. Unicode defines upper, lower, and title case properties for characters, plus special cases that impact specific language's use of text.*

*Many developers believe that that a case-insensitive comparison is achieved by mapping both strings being compared to either upper- or lowercase and then comparing the resulting bytes. The existence of functions such as 'strcasecmp' in some C libraries, for example, or common examples in programming books reinforces this belief:*

    if (strcmp(toupper(foo),toupper(bar))==0) { // a typical caseless comparison
  
*Alas, this model of case insensitive comparison breaks down with some languages. It also fails to consider other textual differences that can affect text. For example, [Unicode Normalization] could be needed to even out differences in e.g. non-Latin texts.*

*This document introduces case-folding and case insensitivity; provides some examples of how it is implemented in Unicode; and gives a few guidelines for spec writers and others who with to reference comparison using case folding.* ...

*Consider Unicode Normalization in addition to case folding. If you mean to find text that is semantically equal, you may need to normalize the text beyond just case folding it. Note that Unicode Normalization does not include case folding: these are separate operations.*

-----

As you might have understood from now, the foldcase API needs to add a
normalization step to the case-folding step.

case-folding expands certain characters to longer strings, NFD
normalization even more, NFC normalization will contract them at last
with some additional memory and cpu costs.

Without normalization you will not be able to compare multi-byte
strings properly.

perl has this bug since 5.16. Every other language has this bug also,
but doesn’t brag about proper full foldcase’ing in its docs as perl
does.

For performance cperl and safeclib (my C11 libc) implements `fc` with
NFD. (Same as Apple in its HPFS btw).

Note that not even libc implements a proper `wcsfc()` or
`wcsnorm()`. You cannot compare multi-byte strings in POSIX, only with
gnulib or ICU, but they are massively over-architectured, still
unusable for e.g. coreutils. E.g. grep would really like to find
strings. Only cperl will do so properly after [#332](https://github.com/perl11/cperl/issues/332) has landed (it's
already implemented in safeclib). awk, grep, perl5, perl6, ruby,
python, go, silversearch, go platinum searcher, rust ripgrep, ... do
not. They all fail on normalization issues, and with grep you don't
know if it's multi-byte patched at all.

safeclib is the first library to implement proper foldcasing in
C. FreeBSD will take it from there.

Details
-------

Unicode is pretty established, some use it with the `wchar_t` API in
POSIX, some more as non-POSIX via external non-standardized utf-8 libraries.
The defacto standard there is [utf8proc](https://github.com/JuliaLang/utf8proc), which is now maintained with julia.
This is highly recommended.

gnulib found out about this problem when people started asking for
multi-byte support in the coreutils. People would really like to find
strings also in foreign documents.  So Bruno Haible, the author of
gnulib (and clisp) added libunistring, with support for u32 and u16
and later even u8 (i.e. utf-8 not single-bytes).

The first problem is that gnulib is GPL-infected, the second is that
libunistring is too big and too slow to be usable for the coreutils.
Suse and Redhat added the unsupported multi-byte patch for some
years now, but the situation is still unsolved, and you frequently
hear about 8x slower basic utilities with utf-8 locales.


Multi-byte support
------------------

A good overview is this document:
http://crashcourse.housegordon.org/coreutils-multibyte-support.html

So what's the technical problem?
-------------------------------

Technically you need to search in a range of integers from `1` to
`0x10fff` for case-folding expansions, and then for composed
characters which need to be decomposed.

There are several established ways to search an integer in a known
static large sparse array:

* **linear search** is done by musl libc in [`towctrans.c`](https://github.com/rurban/musl/commits/master), and musl even does
  not stop searching after it cannot find the integer anymore. It always
  does a full range sweep over all ranges.
  I've fixed that, and musl is now as fast as glibc in case transformations.

* perl5 also does linear search, but does it even more stupid than
  musl. It's about 8000x slower than a normal search for unicode
  properties as implemented in cperl. cperl needed it faster, because
  cperl supports unicode indentifiers, and such identifiers need to be
  normalized.  perl does not have case-insensitive identifiers, so
  case-mapping is not done yet, it will be implemented in the next
  month for the `m//i` (case-insensitive regexp match) case. Currently
  when perl needs to do case-transformation it loads some perl source
  code from generated mapping tables, from a big file, transforms this
  into an array, transforms this into a reverse range array, stores
  this reverse range array in some global perl data as INVLIST
  datatype, which is btw. not shared amongst threads or forks, and
  then searches via slow perl source ops in these ranges. You cannot
  possible think of a slower thing to do. Normally you would prepare
  such tables as C code and then generate s ahared library for
  it. Only the external library Encode does it this way, for its
  encodings transformations.  But still, perl5 has the best unicode
  support of all languages, just also the slowest.

* **trie search**: There's a nice helper module in perl `CharClass::Matcher`
  under `regen/regcharclass.pl` which generates C code for some
  typical unicode properties, as trie. It's not a binary trie, it does
  not start in the middle of the range, and then recurses into the
  lower or upper halfs of the integers. It only starts at the top, so
  it's basically a longer linear search, using even more memory than
  a linear search, but it supports utf-8, it even searches in multi-byte
  utf-8, it generates ASCII and EBCDIC, and it will drive into
  recursion overflows when trying to generate more realistic
  tables. Such as the case mapping tables or the normalization tables.

* **binary search**: You start in the middle and recurse into the lower
  and upper halfs. The problem here is the amount of memory needed to
  store the full range of `1..0x10fff`. You don't want to do
  that. Only glibc does that. Search is log n, but memory is n.
  You could binary search over some range tables though.
  
  glibc uses a full unicode array with a bitcompressed scheme of
  the properties.

* **2 or 3-stage tables**: that's what perl `Unicode::Normalize` and
  gnulib/libunistring does and
  [Unicode 5.1 Data Structures for Character Conversion recommends](http://www.unicode.org/versions/Unicode10.0.0/ch05.pdf) recommends.
  Both use 3 nested tables of 256 elements planes. Since the entries
  are sparse, most elements are NULL, and the final tables holds the
  values.  This saves some space, and search is 3.  However space is
  still not optimal. I improved the Unicode::Normalize generated
  tables by using another indirection and store the unique values in
  seperate tables, sorted by element size.  E.g. for the Canonical
  Decomposition table the value lengths are `(917,762,227,36)`, which
  is perfect for this kind of scheme.  But for the Compatible
  Decomposition table the lengths are `(1664,1190,638,109,16,14,1,1)`
  and then a final arabic letter which expands to 18 at the end. This
  one can be special cased, but the rest cannot be optimized to use
  indirection with a 16bit short, you need to use 32bit, and then the
  old scheme is better.
  
  libunistring/gnulib divides its generated tables into 3 levels and
  does some additional manual logic as it sees fit.  For tricky tables
  like the composition table it uses gperf, which goes down to 11Kb
  (array size 1527 for 928 entries).  Some logic is extracted into
  iterators, e.g. the case-folding is locale-specific, and there are
  special rules for turkish and lithuanian, which is added via custom
  iterator passes. This is slow. Think of custom LLVM passes over your
  code. safeclib hardcoded those simple rules.
  
  Note that coreutils will use this eventually, but tried so far over
  10 years already.

* **perfect hashes**: This is what ICU does. But it's only a simple
  perfect hash.

  You could analyze the bit patterns and try to find to fast search
  algorithm for the numbers. gperf does a little bit of this. This
  could be the perfect algorithm as it would use the least amount of
  memory, and would be still pretty fast. Unfortunately there does not
  exist a good perfect hash algorithm for such integer ranges as used
  in the Unicode tables.
  
  I'll try to come up with something new.  A strict hash table as used
  in the most popular schemes via one indirection tables would be too
  big, a hybrid approach would be needed to generate logic branches
  with some nested binary search or hash tables, which in the end also
  can have logic to search in the collision list. It doesn't need to
  be perfect perfect, just optimal. The cost function would be easy,
  as branches, search cost, code size and data size would be easy to
  come up with. But it doesn't exist yet. And Unicode changes its
  tables every year.


As you see with ICU and partially with libunistring the amount of
memory is still massive and prohibitive. coreutils will not use it,
and honestly such a basic problem of string comparison and string
searching should be in the libc, and properly solved. And only this,
not much else. Other unicode properties can be another optional shared
library.
  
That's why I added those functions to
my [safeclib](https://github.com/rurban/safeclib/commits/wcsnorm),
which was written 2008 by Cisco under the MIT license to add the
missing secure C11 Annex K functions with the `_s` suffix. Cisco
stopped at about 60 functions and I recently all the other missing C11
functions, now at 134.  After about 10 years of C11 still
[almost nobody implements full C11](https://rurban.github.io/safeclib/doc/safec-3.0/d1/dae/md_doc_libc-overview.html). You
need to use Windows, Android or Embarcadero on embedded systems, or
you need to add safeclib.

[`wcsfc_s()`](https://github.com/rurban/safeclib/blob/wcsnorm/src/extwchar/wcsfc_s.c) does secure foldcasing, i.e. full Unicode case-folding and
NFD normalization, with the minimal amount of memory used.  It uses my
generated tables for case-folding and canonical decomposition.
case-folding is the extended version of the musl [`towctrans`](https://github.com/rurban/safeclib/blob/wcsnorm/src/extwchar/towctrans.c), fixed to
stop searching early, and normalization with the improved version of 
Unicode::Normalize mkheader with [indirect tables](https://github.com/rurban/safeclib/blob/wcsnorm/src/extwchar/unifcan.h).

[`wcsnorm_s()`](https://github.com/rurban/safeclib/blob/wcsnorm/src/extwchar/wcsnorm_s.c) does normalization to NFC (*soon*), and there exist API's for the
intermediate steps, decompose, reorder, compose, but not the compat
modes as they are too big and should not be used. (only for identifiers
maybe).

