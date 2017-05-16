+++
date = "2017-05-16"
title = "strict hashpairs"
tags = [ "cperl", "hash" ]
+++

# perl5 optionally warns on odd hash elements

    my %h = (0,1,2);

is legal code in perl5. The second pair is constructed with the undef value.
With `use warnings 'misc'` it will warn at least.

    use warnings;
    my %h = (0,1,2);
    => Odd number of elements in hash assignment (WARNING only)

# perl6 throws on odd hash elements

perl6 is sane and strict by default.

    my %h = (0..2);
    => Odd number of elements found where hash initializer expected:
    Found 3 (implicit) elements:
    Last element seen: 2
      in block <unit> at <unknown file> line 1

# cperl 5.27 throws with use strict

Since cperl 5.27.0 use strict added two new keys: **'hashpairs'** and
'names'. 

strict hashpairs ensure that no hashes can get created from lists or arrays with odd elements.

    use strict;
    my %h = (0,1,2);
    => Only pairs in hash assignment allowed while "strict hashpairs", got 3 elements
    Execution of -e aborted due to compilation errors
    
With constant arrays or lists this is even a compile-time error, as seen above.

With map it is even more strict. With map only a missing or a single
pair is allowed to construct a hash, not multiple pairs. 

    use strict;
    my %h = map {$_=>1, $_+1} (0..2);
    => Only pair in map hash assignment allowed while "strict hashpairs", got 3 elements

This was legal in perl5 and is now a run-time error. Net::DNS did it
to construct two pairs in one loop.

    use strict;
    my %h = map {$_} @array;
    => Only pair in map hash assignment allowed while "strict hashpairs", got 1 elements


Typical oddities, which are now forbidden:

    %h = map { $ => (0,1) } (0..3);
    => 1=>3, 2=>0, 0=>1

Only 3 keys, not 4. Because `@h=map{$=>(0,1)}(0..3);print join" ",@h'` 
=> `0 0 1 1 0 1 2 0 1 3 0 1` and the duplicate keys collapse.

    %h = map { $_ } (0..3);
    => 2=>3, 0=>1 (2 keys, of course)

# More warnings

cperl 5.27 added detection for more "Odd elements" warnings, esp.
when a map assigned to a hash produces no pairs.

    no strict;
    use warnings;
    %h = map { $_ } (0..1);
    # => Odd number of map elements in hash assignment
    %h = map { $_ => (0,1) } (0..1);
    # => Odd number of map elements in hash assignment
    
The warning is only produced once for each map, not for every map iteration.

# CPAN Impact

One might think changing the strictness of the language might break a lot of modules.
Thanksfully most module authors already use sane coding principles, only a few
produce multiple pairs per map to a hash.

All of them have been fixed in my distroprefs patches, and some also upstream.

* Net-NDS: https://rt.cpan.org/Ticket/Display.html?id=121680 [rurban/distroprefs@63cd16b](https://github.com/rurban/distroprefs/commit/63cd16b8359d1ccd062f0c4b913fa77b4b8681ff)
* Moose: [rurban/distroprefs@f929f79](https://github.com/rurban/distroprefs/commit/f929f794fc64b5fef3b29c81f5b313c28f60da92)
* DBI: [rurban/distroprefs@2f0c82d](https://github.com/rurban/distroprefs/commit/2f0c82d7e938e8d10420c3d76eab235fbb229fff)
* Class::Tiny [rurban/distroprefs@0205433](https://github.com/rurban/distroprefs/commit/02054335a9c30aa3d5d7abfe7ca6002d5ccd4033)
* MooseX::Types [rurban/distroprefs@e1e3fc0](https://github.com/rurban/distroprefs/commit/e1e3fc0fc6f03a6dcc6afdf9afd4ac85abd6076a)
* Encode [dankogai/p5-encode#100](https://github.com/dankogai/p5-encode/pull/100)

Only one module at all used a double pair in a map, Net::DNS. This was easily fixed.
The other modules use `%opts = @_;` to assign a hash from the pairwise arguments of a
subroutine call. Perfectly fine usage.

It get's crazy with something like 

    my %p = map { %{$_} } @_;

in `Moose/Util/TypeConstraints.pm`.

Or

    my %attrs = map { %{ Class::MOP::Class->initialize($_)->_attribute_map } }
                reverse $self->linearized_isa;

in `Class/MOP/Class.pm`.

    my %defaults = map { ref $_ eq 'HASH' ? %$_ : ( $_ => undef ) } @spec;

in `Class/Tiny.pm`

    my %order = map {
                my $order = $_;
                map { ( $_ => $order ) } @{ $dbh->{sql_init_order}{$order} };

in DBI. Here you also see the manual prevention of the problem described
below, protecting the iteration key from the global iterator in nested
map loops.

These cases just deserve a `no strict "hashpairs"`.

# Sideeffects and wrong order of evaluation in map

And now look at these oddities, detected by Patrick Cronin and rafl for their
new [Map::Functional](https://github.com/PatrickCronin/Map-Functional/)
module.

    sub x{$_,"ouch"}; %h = map { $_ => x } (0..3);
    => %h => 3=>ouch, ouch=>3, 1=>ouch, 2=>2, 0=>0
    
5 not 4 keys. Still the normal list comprehension problem..
But what if the value changes the key?

    sub x{$_ = "ouch"}; %h = map { $_ => x } (0..3);
    => %h => ouch=>ouch

A sideffect in the value evaluation changed the key, because the `$_`
inside the x subroutine is the same as the global `$_` loop iterator
inside map.  They experience problems with the global topic trampled
over inside a loop by various other ops, just as `while (<>){}` called from
the value, which changed the key.

Too bad [perl5 removed the lexical `$_` topic](http://blogs.perl.org/users/rurban/2016/04/the-removal-of-the-lexical-topic-feature-in-524.html). This
would at least have saved the loop iterator.

But it is worse than that. It is even broken without a lexical `$_`,
and without a function.

    %h = map { $_ => ($_ = "ouch") } (0..3);
    => %h => ouch=>ouch

All the values inside the map are computed at once, hence the first
`$_` is changed also, and the list produced by the map block is
consumed later, when the block is done.  In a proper language with
proper of left to right evaluation order the key would be consumed
first, and then the value.

The underlying design problem is that the map lambda has no formal argument
list, where you could enforce that order. `map sub(a,b){ a => b } (0..3)`
perl5 just uses a block body with a silent `($_)` lambda
signature and the return value(s) just spill over to the stack.

But it is still solvable by detecting lists inside map blocks and
consume them one by one.

    map { $_ => ($_ = "ouch") } (0..3);

is roughly compiled as:

    mapstart { stmt, stmt } mapwhile rv2av const(AV)

I might change it to:
    
    mapstart { stmt; mapwhile; stmt } mapwhile rv2av const(AV)
    
The embedded mapwhile op would consume the first element, push it into
the stack and continue. This would make hash assignments via map much safer.

# strict names

**strict 'names'** is not yet enabled. It will check for valid
identifiers being created from strings under no strict 'refs'. Which
helps in [fighting invalid identifiers](unicode-identifiers.html)
being created, which cannot be handled by the rest of perl, and
esp. since 5.16 with additional embedded NUL.  cperl 5.26 made
embedded NUL's and invalid unicode
identifiers [illegal](https://github.com/perl11/cperl/issues/233),
and [normalizes unicode identifiers](https://github.com/perl11/cperl/issues/228). But
there's still room left to create invalid and potentially harmful
unicode names. Some cases are only warned against.  strict names will
ensure no illegal name will get created.

And it clashes with a reserved VMS hint. Means on VMS strict names will be a no-op.

# Comments on [/r/cperl](https://www.reddit.com/r/cperl/comments/6bgya8/strict_hashpairs/)
