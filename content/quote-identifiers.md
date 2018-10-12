+++
date = "2018-10-12"
title = "Removal of the perl4 ' package seperator"
tags = [ "cperl" ]
+++

The removal of the old and deprecated perl4 single quote character `'`
as valid package seperator in cperl went through various steps.
It's also explained in [perldata](http://perl11.org/cperl/perldata.html#Identifier-parsing).

There are still two package separators in perl5:

A **double colon** (`::`) and a **single quote** (`'`).  Normal
identifiers can start or end with a double colon, and can contain
several parts delimited by double colons.  Single quotes within **perl5**
have similar rules, but with the exception that they are not legal at
the end of an identifier: That is, `$'foo` and `$foo'bar` are legal,
but `$foo'bar'` is not.

In **cperl** only the double colon (`::`) is a legal package
separator, the perl4 package seperator `'` was made illegal with
5.26c, and since 5.28c is now legal part of the identifer.  Full
support for the single quote `'` as part of an identifer came with
5.28c, and matches now the behavior of perl6.

    sub isn't { } # parsed as isn't since 5.28c, illegal with 5.26c,
                  # before parsed as isn::t
    isn't()       # parsed as isn't since 5.28c, illegal with 5.26c,
                  # before parsed as isn::t

Differences and caveats, when being expanded in strings:

Note that hashes are not expanded, e.g. `"%file's"` stays `"%file's"`,
only scalars and arrays are expanded.

    my $file = "test";
    my @file = ("a", "b");
    if ($^O !~ /c$/ or $] < 5.026) { # pre 5.26c
      is("$file's test", " test");   # parsed as file::s
      is("@file's test", " test");
    }
    elsif ($^O =~ /c$/ and $] >= 5.026 and $] < 5.028) { # 5.26c
      is("$file's test", "test's test"); # parsed as $file . "'s test"
      is("@file's test", "a b's test");
    }
    elsif ($^O =~ /c$/ and $] >= 5.028) { # 5.28c
      is("$file's test", " test");   # parsed as $file's. " test"
      is("@file's test", " test");
    }

perl6:

    no strict;
    my $file = "test";
    my @file = "a", "b";
    is("$file's test", " test");        # parsed as $file's. " test"
    is("@file's test", "@file's test"); # @ is not expanded anymore
    
There's no plan to follow the perl6 syntax decision to not expand the
`@` sigil in strings anymore. This is a fundamental perl5 feature and
widely (ab)used for various cases, which cannot be changed. We also
don't find that breaking change useful.

Additionally, if the identifier is preceded by a sigil -
that is, if the identifier is part of a variable name - it
may optionally be enclosed in braces.

So to properly expand such a scalar string without the quote you
need to use `"${file}'s"`.

      is("${file}'s test", "test's test");

It worked for a short time in 5.26c without the `{}` quoting, but only
in this particular version.

There are still some modules on CPAN which rely on the wrong outdated
perl4 behaviour. Mostly test related modules which insist on using `isn't`
as a method name. There's nothing wrong in using `isn't` as name, just
beware that it is not expanded to `isn::t` anymore. I.e. it's in the 
main module namespace, and not a method called `"t"` in the `"isn"` sub
namespace. It's also illegal with 5.26c and cannot be parsed.

For XS modules there's the `PERL_NO_QUOTE_PKGSEPERATOR` definition.
It is defined in cperl since 5.26c. Affected are only `Sub::Name` and
`Sub::Util`. `Sub::Name` is broken for a long time and should not be used,
and `Sub::Util` is distributed in cperl and perl5 core.

# Comments on [/r/cperl](https://www.reddit.com/r/cperl/comments/9niw89/removal_of_the_perl4_package_seperator/).
