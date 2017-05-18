+++
date = "2017-05-18"
title = "strict names"
tags = [ "cperl", "security" ]
+++

# Consistent identifier parsing rules

perl5 and cperl older than 5.27.0 accepts any string as valid
identifier name when being created under `no strict 'refs'` at
run-time, even when most such names are illegal, and cannot be handled
by most external modules.
Even invalid unicode is allowed.

cperl 5.26 fixed embedded NUL's and invalid unicode
identifiers [illegal](https://github.com/perl11/cperl/issues/233),
and
[normalizes unicode identifiers](https://github.com/perl11/cperl/issues/228) in
the parser.

Since cperl 5.27.1 dynamically created names are treated the same way
as when they are parsed. Which means illegal utf8 names are
rejected, unicode names are now normalized at run-time in the rv2sv
OP, via `${"string"}`.

# strict names

**strict 'names'** is now implemented, included in the default and
enabled with cperl 5.27.1. It checks
for [valid identifiers](http://perl11.org/cperl/perldata.html#Identifier-parsing) being
created from strings under `no strict 'refs'` at run-time to match the
same rules as when they would have been created at compile-time by the
parser. Which helps
in [fighting invalid identifiers](unicode-identifiers.html), which
cannot be handled by the rest of perl.
But there was still room left to create invalid and
potentially harmful utf8 names at run-time via `no strict 'refs'`.
strict names ensures no illegal name will get created.

Note that p5p insists that illegal identifiers are still legal to
create at run-time. Only compile-time illegal identifiers are illegal.

Currently it clashes with a reserved VMS hint. That means on VMS
strict names will be implemented in a slower way, via a hints hash
key, not a hints scalar bit.

# Examples

* This was legal before and is now illegal:

```
    use strict; no strict 'refs';

    ${"\xc3\x28"}
    
    my $s = "\xe2\x28\xa1";
    ${$s}
    
    ${"$s\::xx"}
    
    ${"\cTAINT"}
```

=> Invalid identifier "\24AINT" while "strict names" in use

* This symbol is since 5.26 normalized, previously not.

```
    use strict; no strict "refs";
    my $café = "café";   # <c, a, f, e, U+0301, U+0301>
    print $café;         # <c, a, f, U+00E9>
```

Before:

    Empty
   
Now:

    café

* And the illegal UTF-8 variant:

```
     use strict; no strict 'refs';
     my $café = "café"; # <c, a, f, e, U+0301, U+0301> 
     print ${$café};    # <c, a, f, U+00E9>
```

Before:

    Global symbol "$café" requires explicit package name (did you forget to declare "my $café"?) at -e line 3.

Now:

    Malformed UTF-8 character: \x81 (unexpected continuation byte 0x81, with no preceding start byte) in scalar dereference at -e line 3.
    Malformed UTF-8 character (fatal) at -e line 3.

# CPAN Impact

Not many CPAN modules are affected by strict names being on by
default.  This is expected as strict names mostly protects against
run-time security attacks.

* Pod-Perldoc: https://rt.cpan.org/Ticket/Display.html?id=121771

    `my $version = do { no strict 'refs'; ${ '$' . $class . '::VERSION' } };`
    => Invalid identifier "$Pod::Perldoc::VERSION" while "strict names" in use
    
cperl caught the wrong leading `$` here.

# Comments on [/r/cperl](https://www.reddit.com/r/cperl/comments/6bvokz/strict_names/)
