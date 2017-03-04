+++
date = "2017-03-03"
title = "cperl classes"
draft = true
tags = [ "cperl", "oo" ]
+++

cperl being a perl11, i.e. 5+6=11, of course means that cperl classes
are designed after perl5 and perl6 classes. perl5 does not have a
builtin class keyword, but allows to add keywords to be added at
runtime. cperl and perl6 of course do have a builtin class keyword.

The backcompat problem with a new builtin keyword is, that some usages
of variables, package or function names will not work anymore, because
the new keyword stepped over it. In the current class development
[branch](https://github.com/perl11/cperl/commits/featurex/gh16-multi)
this is indeed a problem for the existing `B::class` method which
cannot be imported anymore and be used as `class($op)`. Instead all
these usage have been replaced with `B::class($op)`.
Technically this can be avoided by hijacking only the first token
in a statement, and let those be valid cperl terms:
`$class`, `sub class {}`, `package class;`

    class Test::Builder::Module {
        has int $Child_Error;
        has $Parent;
        has $Parent_TODO;
        has str $Name;
        has str $Child_Name;
        has Bailed_Out_Reason;
        has Bailed_Out;
        has bool $Have_Plan;
        has $No_Plan;
        has $Skip_All;
        has @Test_Results;
    }

    class Test::More is Test::Builder::Module {
    }

Just look at the
[Perl6 Class Tutorial](https://docs.perl6.org/language/classtut) and
replace all "traits" behind signatures with attributes, e.g.  `method
area() returns Int {}` => `method area() :Int {}`, or `has Bool $.done
is rw;` => `has Bool $done :rw;`, leave out the new secondory sigils,
e.g. `has Int $.x;` => `has Int $x;`, and you got the cperl syntax.

    class Point {
        has Int $x;
        has Int $y;
    }
     
    class Rectangle {
        has Point $lower;
        has Point $upper;
     
        method area() :Int {
            ($upper->x - $lower->x) * ( $upper->y - $lower->y);
        }
    }
 
    # Create a new Rectangle from two Points
    my $r = new Rectangle(lower => new Point(x => 0, y => 0),
                          upper => new Point(x => 10, y => 10));
    say $r->area(); # OUTPUT: «100␤» 

The old perl5 design for this was:

    package Point; use fields qw(x y);
    sub new {
        my str $name = shift;
        bless {@_}, $name;
    }
    
    package Rectangle;
    use base ('Point'); use fields qw(lower upper);
    sub new {
        my str $name = shift;
        bless {@_}, $name;
    }
    sub area {
        my Rectangle $self = shift;
        my ($lower, $upper) = ($self->{lower}, $self->{upper});
        ($upper->{x} - $lower->{x}) * ($upper->{y} - $lower->{y});
    }
    my $r = new Rectangle(lower => new Point(x => 0, y => 0),
                          upper => new Point(x => 10, y => 10));
    print $r->area(); # OUTPUT: «100» 

With the old pre-5.10 pseudo-hashes the field names `upper`, `lower`
as hash keys where compile-time optimized to linear-time array access
to the magic `@Rectangle::FIELDS` array.  The hash was made restricted,
ensuring typos in the field names would lead to compile-time errors,
when those keys did not exist.

# Encapsulated fields

In perl6 fields are encapsulated. *"Just as a my variable cannot be
accessed from outside its declared scope, fields are not accessible
outside of the class. This encapsulation is one of the key principles
of object oriented design."*

perl5 fields were optionally private if given a `_` prefix, but you
could always use the magic `@FIELDS` array and hash in the first slot
to access the private fields also.

cperl fields are encapsulated, but the trait syntax is different to perl6.
The Moose syntax even more.

...
