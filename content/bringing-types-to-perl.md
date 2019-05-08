+++
date = "2017-03-10"
title = "Bringing types to perl"
draft = true
tags = [ "cperl", "oo" ]
+++

And of course a proper object system.

Subtitle: *Why a MOP is not always a good idea*

Talking very broadly about perl, with lots of references to lisp,
smalltalk, C++, javascript, python, php and ruby.

# About

Reini Urban. Software maintainer, previously engineer, surfer and architect.

Old Lisp guy, with using perl as system glue (the relevant
[xkcd.com/312/](https://www.explainxkcd.com/wiki/index.php/312:_With_Apologies_to_Robert_Frost)).

Maintainer of **parrot**, the cross-language, perl6 abandoned, virtual
machine framework.

Maintainer of **potion**, the *_why the lucky stiff* improved lua with
classes fron IO, a mop and a jit in <10k lines. Just 200x
faster. Originally thought for ruby (just with a strange stack
syntax), but also usable as VM for perl or python.

Maintainer of the **perl5 compiler**, compiles to C. Used in production
for decades.

Forked perl5 to **cperl**, a perl with classes, a better backcompat
perl5 with perl6 features (5+6=11).

# Types, OO, MOP

There are type systems and there are type systems.  Nominal or
structural, co variant/contra variant, sound or unsound, making it
slower or making it faster, static or dynamic, gradual or optional,
hated or beloved.

What nobody knows, perl5 always had room for types built-in.
`my Coffee $c;` assigned the type `Coffee` to the scalar variable `$c` at
compile-time. The type Coffee needed to exist already, i.e. it needed
to be a properly declared package. Internally every package (or "class")
defines a global symbol-table names space, a hash of symbols under main.
i.e. `%main::Coffee::` (called a stash, "symboltable hash").
There are some modules on CPAN which declares types on some of its variables.

types are compile-time guarantees and hints for the compiler and optimizer.

types structure classes and method dispatch.

types document code, makes code stricter, with more static
guarantees. You can gradually switch from obsessive test driven
development with test suites running hours, to obsessive statically
typed code, with over-architectured refactoring, and not being able to
debug into no compile-time errors, which were previously dynamic
errors.

This concept came with Common Lisp and its famously optimizing
compiler, called [python](http://www.sbcl.org/manual/#Handling-of-Types).
Yes, really, the CMUCL compiler, now still alive as SBCL. Types and compiler
pragmas were purely optional, as every symbol and variable carried its
type with itself.  `(or (>= safety 2) (>= safety speed 1))`

    (defmacro my-1+ (x)
        `(the fixnum (1+ (the fixnum ,x))))

Statically typed variables loose all of its types at run-time - if you
strip it from its dwarf sections, but nobody does run-time type
introspection via dwarf besides [Stephen Kell](https://www.cl.cam.ac.uk/~srk31/), just via horrible C++
RTTI.

Object systems are basically classes, i.e. types, declared with fields
and methods. The optimizer figures out the object layout according to
the type hierarchy, the fields and methods.

A MOP ("meta object protocol") was invented to change the default
behavior for objects, methods and classes, basically to make them
better and slower.  It came up with the differences in LISP frames vs
CLOS. We had a huge slow monster CLOS, and many small elegant but
limited frames systems.

Now we know basically three types of object systems:
1. classic hierarchical compile-time classes with inheritance,
shared methods per class (C++),
2. dynamic prototypes with all the methods in the objects (javascript),
3. mixins with compile-time composition of classes, in
contrast to run-time dispatch to parents via inheritance (flavors,
CLOS, ruby include).

With a MOP you are able to change a classic system to a prototype or mixin
system, and vice versa.

# The case for perl5

As everybody knows perl5 is famous for destroying object oriented
programming, and ruby and perl6 are famous for doing too much object
oriented programming.

perl5 never had a proper object system. like javascript and lua, but
unlike most other languages. ruby is basically a proper perl5 with
types, everything is an object and a slow method call. while python
had at least signatures.

there are many object systems for perl5, but all make them 10x slower
and not 10x faster as it should be.  so a proper object system for
perl5 easily changes the whole situation for the ones who still work
with perl, even of everybody else already switched to python, ruby,
javascript, java or go.

# core types vs user types



# soundness vs optimizations


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
as hash keys were compile-time optimized to linear-time array access
to the magic `@Rectangle::FIELDS` array.  The hash was made restricted,
ensuring typos in the field names would lead to compile-time errors
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

# Anon classes

Intermediate classes create via role mixins (the `does` keyword) are
stored in the class slot of every object and refer to stashes.
But when you mix types or multiple classes combined via `and` or
`or` you cannot use a stash, you'd need a list of stashes.
perl6 solved this problem by switching from stashes to objects.
perl5 solved this via creating temp. anon classes to hold mixins, and
mro/@ISA to support multiple inheritance.

...
