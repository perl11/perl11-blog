+++
date = "2018-09-11"
title = "cperl classes"
#draft = true
tags = [ "cperl", "oo" ]
+++
# Subtitle: *Why a MOP is not always a good idea*

cperl being a perl11, i.e. 5+6=11, of course means that cperl classes
are designed after perl5 and perl6 classes. perl5 does not have a
builtin **class** keyword, but allows to add keywords to be added at
runtime. cperl and perl6 of course do have a builtin class keyword.

The backcompat problem with a new builtin keyword is, that some usages
of variables, package or function names will not work anymore, because
the new keyword stepped over it. With the current cperl 5.28 release
this is indeed a problem for the existing `B::class` method which
cannot be imported anymore and be used as `class($op)`. Instead all
these usage have been replaced with `B::class($op)`.

Technically this can be avoided by hijacking only the first token
in a statement, and let those be valid cperl terms:
`$class`, `sub class {}`, `package class;`

# An example

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
replace all "traits" behind signatures with attributes.

e.g.

`method area() returns Int {}` => `method area() :Int {}`,

or

`has Bool $.done is rw;` => `has Bool $done :rw;`,

leave out the new secondory sigils,
e.g.

`has Int $.x;` => `has Int $x;`, and you got the cperl syntax.

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
    say $r->area; # OUTPUT: «100␤» 

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
    print $r->area; # OUTPUT: «100» 

With the old pre-5.10 pseudo-hashes the field names `upper`, `lower`
as hash keys where compile-time optimized to linear-time array access
to the magic `@Rectangle::FIELDS` array.  The hash was made restricted,
ensuring typos in the field names would lead to compile-time errors
when those keys did not exist.

With perl6 or cperl fields you've got the same feature; just a
different, more functional implementation. "functional" meaning
features are hidden between functions, not datatypes. Supporting
datatypes in an API will forever restrict it's usage to this specific
datatype, you will not be able to change the underlying structures and
algorithms. This was the biggest mistakes perl and python did at the beginning.

# Encapsulated fields

In perl6 fields are encapsulated. *"Just as a my variable cannot be
accessed from outside its declared scope, fields are not accessible
outside of the class. This encapsulation is one of the key principles
of object oriented design."*

perl5 fields were optionally private if given a `_` prefix, but you
could always use the magic `@FIELDS` array and hash in the first slot
to access the private fields also.

cperl fields are encapsulated, but the trait syntax is different to
perl6.  You should use the method syntax, not a hash or array access
syntax. Internally this method is then compiled to the most efficient
op or method.

The Moose syntax is more different to perl6 than cperl. And it's
implemention is beyond naive. But theoretically this could be
improved, the biggest problem is still the troublesome syntax, based
on the naive implementation restrictions.

With the new cperl fields API you can inspect all defined fields at
run-time.

    # return-value of Mu::fields or classobj->fields
    class Foo {
        has $foo;
        has @bar;
        has %baz :const;
    }
    my @fields = Foo->fields;
    print $fields[0]->name; # foo

With cperl classes the fields methods returns a list of fields
objects, representing the has declarations of the class with all
imported roles - similar to the perl6
[Metamodel::AttributeContainer](https://docs.perl6.org/type/Metamodel::ClassHOW#(Metamodel::AttributeContainer)_method_attributes|Metamodel::AttributeContainer)
returning [Attribute](https://docs.perl6.org/type/Attribute|Attribute) objects.

Each such returned field object supports the following methods `name`,
`package`, `const`, `type`, `get_value` and `set_value`.  The fields
method is valid for classes and objects. Only objects do have values,
therefore `{g,s}et_value` on a class field is invalid.

# Types, OO

There are type systems and there are type systems.  Nominal or
structural, co variant/contra variant, sound or unsound, making it
slower or making it faster, static or dynamic, gradual or optional,
hated or beloved.

What almost nobody knows, perl5 always had room for types built-in.
`my Coffee $c;` assigned the type `Coffee` to the scalar variable `$c` at
compile-time. The type `Coffee` needed to exist already, i.e. it needed
to be a properly declared package. Internally every package (or "class")
defines a global symbol-table names space, a hash of symbols under main.
i.e. `%main::Coffee::` (called a stash, "symboltable hash").
There are even some modules on CPAN which declares types on some of its
variables.
...

**Types are compile-time guarantees and hints for the compiler and optimizer.**

**Types structure classes and method dispatch.**

**Types document code, makes code stricter, with more static guarantees.**

You can gradually switch from obsessive test driven development with
test suites running hours with over-architectured refactoring,
to obsessive statically typed code, running in 2x faster time,
and not being able to debug into compile-time errors, 
which were previously dynamic run-time errors.

This concept came with Common Lisp and its famously optimizing
compiler, called [python](http://www.sbcl.org/manual/#Handling-of-Types).
Yes, really, the CMUCL compiler, now still alive as SBCL. Types and compiler
pragmas were purely optional, as every symbol and variable carried its
type with itself.  `(or (>= safety 2) (>= safety speed 1))`

    (defmacro my-1+ (x)
        `(the fixnum (1+ (the fixnum ,x))))

Statically typed variables loose all of its types at run-time - if you
strip it from its dwarf sections, but nobody does run-time type
introspection via dwarf besides
[Stephen Kell](https://www.cl.cam.ac.uk/~srk31/), just via horrible
C++ RTTI.

Object systems are basically classes, i.e. types, declared with fields
and methods. The optimizer figures out the object layout according to
the type hierarchy, the fields and methods.

# MOP

A MOP ("meta object protocol") was invented to change the default
behavior for objects, methods and classes, basically to make them
better and slower.  It came up with the differences in LISP frames vs
CLOS. In CL we had a huge slow monster CLOS, and many small elegant but
limited "frames" systems.

Now we know basically three types of object systems:

1. classic hierarchical compile-time classes with inheritance,
   shared methods per class (C++),
   
2. dynamic prototypes with all the methods in the objects (javascript),

3. mixins with compile-time composition of classes, in
   contrast to run-time dispatch to parents via inheritance (flavors,
   CLOS, ruby include).

With a MOP you are even able to change a classic system to a prototype or mixin
system, and vice versa.
Ruby on rails (ab)used the MOP all over which makes it imposible to scale.
With a proper OO design as in Sinatra/Dancer with delegated classes known at
compile-time you can easily scale and optimize such a system. A MOP is a very
poor adhoc method to workaround a proper OO design. It's nice for prototypes, 
such as Moose, which is a very immature adhoc prototype, but it should never
make it into a production system.

#  Difference from class to package

A cperl class is internally a readonly package with a CLASS flag set. 
A class is closed, a readonly block by default. methods and fields are
fixed. If you want dynamic classes use a package. Fields are lexical
members of the class, copied into objects. Fields and methods can be
composed from roles, i.e. copied at compile-time. Conflicts are then
detected at compile-time, and not at run-time as with dynamic packages
and the ISA inheritance mechanism.

Class fields have no variable data layout as with old blessed objects,
where fields could be stored as scalar, array or hash. Class fields
are stored as offset into a not-refcounted array, similar to C structs.
In fact with a the `:native` attribute class objects can be passed via
the FFI to C back and forth. An int field takes 4 byte, a double field 8 byte,
and not 4 words as a normal scalar value.

# Anon classes

Intermediate classes create via role mixins (the `does` keyword) are
stored in the class slot of every object and refer to class stashes.
But when you mix types or multiple classes combined via `and` or
`or` you cannot use a stash, you'd need a list of stashes.

perl6 solved this problem by switching from stashes to objects.
perl5 solved this via creating temporary anon classes to hold mixins, and
`mro`/`@ISA` to support multiple inheritance.

cperl composes mixins at compile-time, without the need to hold anon
classes at all.

# Multiple dispatch - polymorphism

cperl 5.28 does not support the **multi** keyword yet, there's no
polymorph dispatch on methods with the same name (generics) but
varying number and type of arguments yet. polymorphism solves the problem of
generic methods, which do the same but its implemention deviates on the given
arguments. E.g. `+` acts differently on double or int or string.
polymorphism is the proper solution for problems previously solved with
the **overload** pragma.

Internally multi methods will be stored with a name suffix, either
seperated by the public name with `\0` or `@`, followed by the types
of the accepted arguments.  The signature is encoded into the name. This
is similar to C++ name mangling for the run-time dispatcher.

`\0` is a good prefix because in cperl binary names are forbidden, for
security and performance reasons.

`@` would be a good prefix because cperl adopted `@` from
Devel:::NYTProf for names of anonymous subroutines. An "__ANON__"
import method in cperl is named "import@" instead, in Devel:::NYTProf
it would be even named "import@[package.pm,10-12]".  perl5 anonymizes some
names when the GV symbol is being thrown away to `__ANON__`, esp. with
import methods.

# Limitations

5.28 still has some class [limitations](https://perl11.github.io/cperl/perlclass.html#LIMITATIONS).

The number of fields is limited, as in C.

The inliner is not yet implemented, so field index fixups with roles are not supported yet.
When copying a method from a role to a class, and the field index from the role method would
be different to a field index in the resulting class, the method is not yet fixed up to the
new indices. A temp. solution would be to change the ordering of the roles, or to use the 
`$self->field` method syntax in the role method. This requires the not yet finished inliner.
Currently we can only alias composed role methods and we don't change the ordering of the fields.

eval 'class {}' fails

A class cannot be created in an eval block or subroutine. The pad lookup is still global and
not per optional CvPADLIST. During development of cperl 5.28 I found the 
[severe limitations](https://github.com/perl11/cperl/issues/354) of the perl5 pad design,
the delegation of FAKE pads into nested scopes.
upvalues are not copied or delegated to the real slot in the outer pad, but just marked as NULL FAKE pad.
This led to severe compiler bugs, only fixed in 5.28.

i.e.

    my @a[1];
    sub { $a[1] = 1 }->();

missed the compile-time error inside the closed-over sub.
Also all uoob (compile-time out-of-bounds checks) optimizations were missing on those nested fake PADs.
So I had to add a new pad API `pad_findmy_real` to find the real pad/type of a nested lexical variable.

# Comments on [/r/cperl](https://www.reddit.com/r/cperl/comments/9evcew/cperl_classes/).
