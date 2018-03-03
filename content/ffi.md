+++
date = "2017-06-13"
title = "cperl ffi"
tags = [ "cperl", "feature" ]
draft = true
+++

# extern sub NAME (SIGNATURE) :RETURNTYPE;

With perl4 Larry wrote into his TODO list a FFI, foreign function
interface, as one of the most important features. dlopen, dlsym,
dlcall.  With perl5 the XS interface was introduced, which is more
stable, but this still requires an installed C compiler to create a
shared glue library.  With a FFI in perl core, no compiler and C
programming knowledge is required, you just need to follow the
documentation of an external library to be able to use it.

The idea is to declare a subroutine as **native**, with a proper
signature and return type, and optionally in which shared library it
can be found, what the calling convention of the shared library is,
and how strings should be en/-decoded.
You can preload a shared library with DynaLoader and the ffi will
just find the name in it.

perl6 then declared
a [proper specification](https://docs.perl6.org/language/nativecall)
for it's NativeCall feature, which we largely follow, and mix
naturally with our cperl signature declaration.  There are the obvious
language feature translations, like perl6 traits are cperl attributes:

perl6:
`sub my_version(int32 is rw, int32 is rw) is native('foo') returns int32 { * }`

=> cperl:
`sub my_version(int32 $i, int32 $j) :native('foo') :int32;`

# Differences

* trait `is NAME(ARG)` => attribute `:NAME(ARG)`. Like in Perl5.

* return type as subroutine attribute (as with cperl signatures). 
  No `returns` as in Perl6, no `->` as in Python.

* no `{ * }` block. Just a blockless declaration. The body is specified externally.
  Like in C.

* required signature name. Perl6 native signatures don't need names
  for its parameters, cperl does. This uses the same signature parsing
  and CvPADLIST storage for its mandatory types. With normal
  subroutines types are only optional. With the name we can throw
  better error messages, and C header declarations mostly include the
  name also, although it is optional in C and Perl6.

* no `is rw` trait. In perl5/cperl all arguments are copied by
  default, i.e. call-by-value.  readonly-ness is declared via
  `:const`, not `is ro` - `(int $i :const)`.  A reference aka
  call-by-reference is declared in cperl via the reference syntax,
  e.g. `(int \$i)`. This would be a `Pointer[int]` type in perl6,
  and `*int` in C.
  
# Calling Convention

Argument types are mandatory, the default return type is **:void**.
The signature is compile-time checked as every other function call,
just better because of the mandatory types. Besides the already
defined [coretypes](http://perl11.org/cperl/perltypes.html#coretypes),
there exist
also [ffi-specific stdint types](http://perl11.org/cperl/lib/ffi.html),
which map naturally to the C types. Same as in Perl6.  As in C
primitive types are copied, aggregate types called by
reference/pointer. Technically an IV is passed as-is from the SvIVX to
the register or stack value, casted to the correct target-size
(e.g. int8, int32, ...).  A reference is passed as pointer to a
pointer type, e.g. `int \$i` is passed as `*int` and uses the SvIVX
slot of the value. Same for SvPVX slots of strings.

Strings can optionally be encoded in the translation to C and
back via the `:encoded(NAME)` attribute.

The platform and library specific supported libffi calling conventions
can be specified with the [`:nativeconv(ABI)`](http://perl11.org/cperl/lib/attributes.html#nativeconv-STRING) attribute. This is only
useful for some platforms, such as 32-bit Intel x86
with
[7 different](https://github.com/libffi/libffi/blob/master/src/x86/ffi.c#L227) calling
conventions for shared libraries: SYSV, STDCALL, PASCAL, THISCALL,
FASTCALL, MS_CDECL (the default) and REGISTER.

Structs and unions are passed in SvPVX buffers, and can be either read
and written via pack/unpack, or via ffi helpers, but usually you just
pass a pointer to such a buffer, and define accessors for such a
struct.  [Native arrays](https://github.com/perl11/cperl/issues/14)
`my @a :int` of type `:Array(:int)` are not yet supported, you still
have to manually access the buffers. Later such arrays and structs
will be represented in cperl directly and passed from and to C via the
FFI. A struct will be a typed native class, with the fields layout
usable from C. I.e. those fields will not be refcounted.

```
class Point :native {
    has int $x;
    has int $y;
    has str $comment;
}
```

# Improvements

perl5 as well as perl6 cannot deal with [variables in attributes](attributes-args.html).
All attribute arguments are either constant barewords, constant strings or numbers
or are eval'ed unsafely at run-time via Attribute::Handler.

With cperl attributes can now use variables in attributes for lexical
my declarations and subroutines.

This enables now special dll naming rules at run-time.
```
my $libname = "mysqlclient";
$libname = "cygmysqlclient-18.dll" if $^O eq 'cygwin`;
    
sub mysql_init($mysql_client :ptr) :ptr :native($libname);
```

This is important for an FFI, as there's no general naming convention
for shared libraries, only for the import library which is linked with `-lname`.
But the underlying shared library is usually versioned, which sometimes requires
special application and architecture logic.

# Syntax Comparisons



# Comments on [/r/cperl](https://www.reddit.com/r/cperl/comments/6bvokz/cperl-ffi/)
