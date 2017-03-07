+++
date = "2017-03-07"
title = "Unicode Identifiers"
tags = [ "cperl", "security" ]
+++

# Binary names with 5.16

With perl 5.16 added support for binary names, announcing it as
support for unicode names. Unicode names were already supported since
5.8.4 with a negative length stored in the hash key of the symbol.

Supporting binary names without any supporting measures opened huge
security holes, as names are mapped 1:1 to filenames when searching
for a package, and as we know the C API for files or names just
ignores a \0, leading to inconsistencies. And you could now easily
hide payloads in package names. Remember that p5p never announced this
problem and feature, they only announced it as improved and full
unicode support for names.  In the following years I had to fix most
of the problems with binary names support, but many critical modules
still have no idea, and are still vulnerable. Even the new perl5
maintainer has no idea as he showed in his YAPC talk about XS
programming. He happily used the old `gv_` interfaces not supporting
\0, and there's no upgrade path in perl5 for old modules to avoid those
security holes.

Well, with unicode this would not have been a big problem, as our used
encoding UTF-8 does not support \0. It's also illegal.
Only with cperl-5.26 we finally got back safe names, \0 is illegal again.

But here we want to talk about the unicode problems when a language
decides to embrace unicode names. perl5 prides itself by being one of
the scripting languages with the best unicode support.  Well, the
libraries and strings, yes. But the language itself is still horribly
unicode unsafe.

The unicode consortium published many security addendums, as TRnn.
Most of them are targetted to html forms, domains names used in
browsers or DNS servers, and email names. The problem with unicode is,
that different names are not identifiable as such, and thus you can
easily fool someone to click on a wrong url. Identifiers need to be
identifiable and restricted.  perl5 and perl6 pride themselves of
anything goes, it does not enforce opinions on their users. Well, it's
still insecure.

The simpliest unicode problems are tricks with illegal UTF-8
encodings.  This is also relevant to strings and therefore mostly
fixed in perl5 and cperl.

But there are many more security problems in most programming
languages with unicode support. Only cperl, python3 and perl6 fixed
some of them, by doing normalization of its identifiers.
I didn't see any effort in all the others, besides java.

The most basic overview is at http://websec.github.io/unicode-security-guide/.
Go read it.

*"Because Unicode contains such a large number of characters and
 incorporates the varied writing systems of the world, incorrect usage
 can expose programs or systems to possible security attacks. This is
 especially important as more and more products are
 internationalized. This document describes some of the security
 considerations that programmers, system analysts, standards
 developers, and users should take into account, and provides specific
 recommendations to reduce the risk of problems."*

The most improtant documents are

* [TR31 Candidate Characters for Exclusion from Identifiers](http://www.unicode.org/reports/tr31/#Table_Candidate_Characters_for_Exclusion_from_Identifiers).
* [TR36 Unicode Security Considerations](http://www.unicode.org/reports/tr36/).
* [TR39 Unicode Security Mechanisms](http://www.unicode.org/reports/tr39/).

In short, those problems need to be fixed:

# Mixed scripts

A written language is defined by its scripts (i.e. "alphabets"). Some
languages allow multiple scripts, such as Japanese using characters
from Chinese (Kanji/Han), Katagana (modern japanase) and Hiregana
(the old middle-age script used by women).  So if you want to support
japanese you need allow all these three scripts to be used in a program,
without any declaration. Similar for Korean, which sometimes also use some old
Han/Chinese characters, and Chinese which uses the biggest set of
characters Han, plus one additional educational script, called Bopomofo.

The problem is very apparent with Cyrillic and Greek. Both are
different languages, but use almost the same characters, which are not
identifiable in any font. If the character is a Greek or Cyrillic
symbol, or if it's one of the mathematical symbols.

So strict mixed-script profiles for identifiers forbid the default
usage of Greek and Cyrillic characters in the same program.

In cperl, which is currently the only unicode safe language, this
is forbidden:

    use utf8;
    my $Γ = 1;
    if ($Г) { warn; }

`use utf8` declares that identifiers can be unicode, utf-8 encoded.
`my $Γ = 1` sets a scalar lexical variable to 1, with the name `Γ`.
What you don't see, only the parser, or if you inspect the program
binary, e.g. with od, is that the first Γ character is the greek
gamma, and the second variable uses the cyrillic gamma.
Only with a restricted identifier profile you will see the problem.

cperl does this:

    $ cperl5.26.0d-nt -e'use utf8;my $Γ = 1;if ($Г) { warn }'
    Invalid script Cyrillic in identifier Г) { warn }
    for U+0413. Have Greek at -e line 1.

I.e. it allows the first greek character in a name to be used without
declaration of a foreign script, but then fails when a cyrillic
character in a name appears. With such characters in strings or
buffers the user has to care, but with identifiers the parser has to
care, as the identifier is not identifiable anymore.

When a user really wants to use names in multiple languages in a
program, he needs to declare them beforehand, so the casual reader is
aware of the mixed scripts.

    use utf8 ("Greek", "Cyrillic");
    my $Γ = 1;
    if ($Г) { warn }'
    
is now the valid variant. But note that mixing Cyrillic and Greek is
still frowned upon, and needs to be warned, even when being declared
as such.

Similarily, some scripts can be used undeclared, and some need to be
declared.  These recommendations are all specified in the TR39
Restriction levels.

# Visual spoofing

Unicode is pretty good in defining what characters are allowed as
first character in an identifier, and what characters may
follow. These classes are declared in the `ID_Start` and
`ID_Continue`, see
[TR 31 Lexical_Classes_for_Identifiers](http://www.unicode.org/reports/tr31/#Table_Lexical_Classes_for_Identifiers)
for the precise rules properly used in most languages with unicode
support.

I know only of one bug in these tables, the U+3164 HANGUL FILLER is
wrongly specified as ID_Cont. Thus in perl5 this is valid:

    perl -e'use utf8; $aㅤb == 2;'

but cperl detects the problem:

    cperl -e'use utf8; $aㅤb == 2;'
    Unrecognized character \x{3164}; marked by <-- HERE after e utf8; $a<-- HERE
    near column 13 at -e line 1.

Same problem for the U+ffa0 HALFWIDTH HANGUL FILLER. See also
https://github.com/jagracey/Awesome-Unicode#user-content-variable-identifiers-can-effectively-include-whitespace
According to according to
http://www.unicode.org/L2/L2006/06310-hangul-decompose9.pdf those two
fillers ᅟ..ᅠ HANGUL CHOSEONG FILLER..HANGUL JUNGSEONG FILLER are the
proper replacements.

But besides those rare bugs, spoofs and confusables are much more common.
I only know of very few languages which actually detect those problems.

Spoofs are certain trick character combinations.

Popular spoof attacks were the Paypal.com IDN spoof of 2005. Setup to
demonstrate the power of these attack vectors, Eric Johanson and The
Schmoo Group successfully used a www.paypal.com lookalike domain name
to fool visitors into providing personal information. The advisory
references original research from 2002 by Evgeniy Gabrilovich and Alex
Gontmakher at the Israel Institute of Technology. Their original paper
described an attack using Microsoft.com as an example. - [visual-spoofing](http://websec.github.io/unicode-security-guide/visual-spoofing/)

A typical bidi-spoof would involve a unicode aware text-editor or
viewer, and identifiers which switch to right-to-left (arabic),
overwrite the previous characters, and maybe even switch back to
left-to-right. Visually the names look the same, but internally the
spoofed name is much longer.

Such spoofs are usually prevented with forbidding mixed scripts.

# Normalization

Other simple spoofs can be be prevented with normalization. This is
what Python3 started to do, also cperl and java.  With normalization
of unicode character sequences all possible and valid character
combinations are compressed to one single normal form. There are two
defined normal forms, NFKC and NFC, interestingly python decided to
pick the wrong one, normalizing to ligatures. cperl normalizes to the
canonical normal form NFC. perl6 decided to normalize to their own
format, called NFD, which allows invalid, private reserved characters
in upper planes, which will be forbidden in upcoming perl5 and cperl
releases.

E.g. `café` (`<c, a, f, e, U+0301>`) is normalized to `café`
`<c, a, f, U+00E9>`.
`café́`, using two combining marks (`<c, a, f, e, U+0301, U+0301>`) is currently allowed.

# Same Script Confusables

There's a whole table of confusables which are still confusable after
restricting mixed scripts and after normalization.
These confusables are typically optionally warned upon.

# Moderately Restrictive Level

cperl as first dynamic scripting language follows the **General
Security Profile** for identifiers in programming languages.

**Moderately Restrictive**: Allow `Latin` with other Recommended or
Aspirational scripts except `Cyrillic` and `Greek`. Otherwise, the same as
[Highly Restrictive](http://www.unicode.org/reports/tr39/#Identifier_Characters),
i.e. allow `:Japanese`, `:Korean` and `:Hanb` aliases.

*"Some characters are not in modern customary use, and thus implementations
may want to exclude them from identifiers.  These include characters in
historic and obsolete scripts, scripts used mostly liturgically, and
regional scripts used only in very small communities or with very limited
current usage.  The set of characters in Table 4, Candidate Characters for
Exclusion from Identifiers provides candidates of these."*

cperl honors the
[TR31 Candidate Characters for Exclusion from Identifiers](http://www.unicode.org/reports/tr31/#Table_Candidate_Characters_for_Exclusion_from_Identifiers).

I.e. You may still declare those scripts as valid, but they are not
automatically allowed, similar to the need to declare mixed scripts.

    use utf8;
    my $ᭅ = 1; # \x{1b45} BALINESE LETTER KAF SASAK

    => Invalid script Balinese in identifier ᭅ for U+1B45

but when declared as such:

    use utf8 'Balinese';
    my $ᭅ = 1; # \x{1b45} BALINESE LETTER KAF SASAK
    print "ok";

    => ok

The scripts listed at "Table 6, Aspirational Use Scripts":
`Canadian_Aboriginal`, `Miao`, `Mongolian`, `Tifinagh` and `Yi`
are included, i.e. need not to be declared.

With this restriction we are close to the implementation of the
Moderately Restrictive level for identifiers by default. See
http://www.unicode.org/reports/tr39/#General_Security_Profile and
http://www.unicode.org/reports/tr36/#Security_Levels_and_Alerts.

With special declarations of the used scripts you can weaken the
restriction level to **Minimally Restrictive**.

Missing for the **Moderately Restrictive** level are warnings on
single-, mixed and whole-script confusables, and warnings on certain
incompatible mixed-script pairs such as **Greek + Cyrillic**.

All utf8 encoded names are checked for wellformed-ness.
