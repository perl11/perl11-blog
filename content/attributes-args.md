+++
date = "2017-05-27"
title = "Attribute arguments"
tags = [ "cperl", "attributes" ]
+++

# perl5 had broken attribute handling forever

perl5 attributes were invented to provide extendable hooks to attach
data or run code at any data, and made for nice syntax, almost
resembling other languages.

E.g.

    my $i :Int = 1;
    sub calc :prototype($$) { shift + shift }

There were a few number of builtin attributes, like `:lvalue`,
`:shared`, `:const`, adding a flag to a function or data, and you could
add package-specific for compile-time or run-time hooks to process arbitrary custom
attributes.

A `&MyClass::FETCH_SCALAR_ATTRIBUTES` hook would be called on every
not-builtin `MyClass::` scalar attribute at run-time, and
`&MyClass::MODIFY_SCALAR_ATTRIBUTES` at compile-time.

If you would want to process attributes in all classes you'd need to add `UNIVERSAL` hooks
or use handlers like `Attribute::Handlers`.
This would simplify declaring code for attributes.

    sub Good : ATTR(SCALAR) {
        my ($package, $symbol, $referent, $attr, $data) = @_;

        # Invoked for any scalar variable with a :Good attribute,
        # provided the variable was declared in MyClass (or
        # a derived class) or typed to MyClass.

        # Do whatever to $referent here (executed in CHECK phase).
        ...
    }
    
Note the last `$data` argument above. This is the optional argument
for an `:Good` attribute, such as in 
`my MyClass $obj :Good(print a number);`. Do you see the problem?

`$data` will be the result of the evaluation of `print a number`.
Which will create this error: `Can't locate object method "a" via package "number"`.
This would be the correct declaration: `my MyClass $obj :Good("print a number");`.
So `Attribute::Handlers` is entirely unsafe by evaluating all attribute arguments.

But Damian was right thinking of the use-cases. Attribute arguments
are needed to attach certain data to a variable of function. He just
didn't implement it properly, as with all of his modules.

E.g. in cperl we added type support via attributes:
`sub calc ($a:int) :int { $a + 10 }` declares calc as returning an `int` type, and the 
`$a` argument to accept `int` types.

For the upcoming cperl ffi (Foreign FunctionCall Interface) we need
attribute arguments more urgently.

`sub random () :native :long;` declares random as native function,
searched in all loaded shared libraries. I.e. `libc` must already be
loaded. It is by default, so this works. But for non-default shared
libraries we need to specify the name of the library.

Look e.g. at this perl6 NativeCall declaration:

```
use NativeCall;
sub mysql_init( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }
```

Of course this syntax is not ideal. 

* `returns OpaquePointer` is abbrevated in cperl to `:OpaquePointer`. 
* `is native('libmysqlclient')` has the syntax `:native('mysqlclient')`. 
* The empty `{ ... }` block is of course left out. Ditto for `{ * }`. This is superfluous syntax.

A ffi declaration is just a declaration without a body. The body is looked up by the native
attribute, in the declared library, and optionally under the `:symbol('mysql_init')` name.
See the [p6 nativecall docs](https://docs.perl6.org/language/nativecall#Changing_names).

cperl syntax:
```
use NativeCall;
extern sub mysql_init( OpaquePointer $mysql_client ) :OpaquePointer :native('mysqlclient');
```

The `extern sub` declaration is syntax sugar, `extern` means the same
as `:native`, it just looks better, as in better languages.

# Attribute arguments

Now to the `:native` argument, the name of library. You saw in the
first zavolaj example the `lib` prefix stated explictly. `is native('libmysqlclient')`

This will not work on windows and cygwin.  cygwin needs a `cyg` prefix
and a version suffix, the dll is called `cygmysqlclient-18.dll`.

On windows the library would be called `libmysql.dll`, but this varies
wildly, as there's no naming convention for shared libs, only for
import libs.

The world is not made for FFI's, just for linking libraries at
compile-time. There a `-lmysqlclient` is enough, on windows this would
find `libmysqlclient.dll.a` or `libmysqlclient.lib`, which is an
import library which refers to the proper versioned name of the
current shared library. Remember that windows does not solve the
versionining problem of shared libraries via symlinks. One does not
load shared libraries directly on Windows.

So your FFI mysql connector would do some little application logic, like
```
    my $libname = "mysqlclient";
    $libname = "cygmysqlclient-18.dll" if $^O eq 'cygwin`;
    
    sub mysql_init( OpaquePointer $mysql_client ) :OpaquePointer :native($libname);
```

It cannot be solved in the native attribute handler unless you add the
version, like `:native('mysqlclient', 18)`. Then the library searcher
can add some magic to find the proper shared library.  But it is
usually done application specific.

But all this will not work in perl5, as perl5 has no proper way to resolve the
attribute argument `$libname` at run-time. What perl5 does is parsing
`:native($libname)` to the string `'native($libname)'` and passes it
to `BEGIN { use attributes ... ':native($libname)'; }`.

Note `':native($libname)'` and not `":native($libname)"`,
i.e. `$libname` is not expanded to it's value, and it would not help much
as the call happens at compile-time, so `$libname` would have been empty still.

What it should have done instead is to inject the code 
`use attributes ... "native($libname)";`, which is the equivalent of

    BEGIN { require attributes; }
    attributes->import(__PACKAGE__, \&msql_init, "native", $libname);

Which means the import call needs to be deferred to run-time. perl5
does this only for **my** variable attribute parsing, but not for functions.

`my $var :native($libname)` would correctly call the importer at
run-time, but `sub random() :native($libname);` would falsely call the
importer at compile-time, and the argument would not be parsed at
all. Everything is passed as string to the importer, and the hook
needs to parse the argument. Hence the Attribute:Handler security
nightmare, simply calling eval on all args. Which is a lot of fun
e.g. with a documentation attribute with `App::Rad`, when your
docstring is eval'ed.

Now with cperl there are now two kind of builtin attributes. The old
:prototype args are still compiled as barewords, but the new :native
and :symbol attribute args (and probably more upcoming) are compiled
as data, with constant strings being compiled at compile-time, and
scalar values being defered to run-time.  Just as with `use attributes
"native", $libname;`

# Internally

Internally perl5 has 3 attrs API's. Two of them are useful, if still broken.

`apply_attrs` is the compile-time variant, passing the verbatim string
with the argument to the attribute import call at compile-time.

This translates `sub func :native($libname)` to 
`BEGIN { use attributes __PACKAGE__, \&func, 'native($libname)'; }`.

`apply_attrs_my` is the run-time variant, passing the verbatim string
with the argument to the attribute import call at run-time.

This translates `my $var :native($libname);` to `my $var; use
attributes __PACKAGE__, \&var, 'native($libname);`.  This is almost
correct. At least the import is done at run-time, and the attribute
handler will have a chance to handle the value of the thing inside the
parens. So eval will work there.

cperl detects in the lexer scalar variables from attribute arguments,
constructs a proper list for the argument,
and passes it to `apply_attrs()`, which then tries to detect needed
run-time deferral. And if so calls `apply_attrs_my()` instead.

This translates `my $var :native($libname);` to 

    my $var; use attributes __PACKAGE__, \$var, 'native', $libname;

And `sub func :native($libname);` to 

    sub func; use attributes __PACKAGE__, \&func, 'native', $libname;

The third internal API `apply_attrs_string` is extremely naive and
only useful to process simple `ATTRS:` token in XS declarations. It
cannot handle utf8, and splits arguments by space, not being able to
handle nested parens. And then it calls the importer at compile-time.

In cperl I added an `attrs_runtime()` API, which looks at the list of
attrs from the lexer, and calls the runtime variant `apply_attrs_my` when
a scalar variable or function call is detected.

So far I treat :native and :symbol barewords as constant strings and
not as function calls.
I.e. `:native(mysqlclient)` does not call the mysqlclient function to return the name.
Attribute::Handler would do that. I'll probably add that with the more explicit 
`:native(&mysqlclient)` syntax.

# Why attributes?

A better idea than attributes to attach data would have been metadata
as methods, because then you could also query the current values. With
attributes you can only set it.

    \&mysql_ffi_fetch->NATIVE = "mysqlclient.6.so";
    print \&mysql_ffi_fetch->NATIVE, \&mysql_ffi_fetch->SYMBOL;

This would be independent of packages, and much easier than with
package specific `FETCH_CODE_ATTRIBUTES` hooks. You just query the
data. And the magic method would be **lvalue**, so it could be used as
getter and setter.

But for compatibility with other languages attributes do make a fine
syntax to declare data properties. So cperl will continue to use the perl5
attribute syntax for perl6 `traits`.

# See also

* [ffi #22](https://github.com/perl11/cperl/issues/22)
* [Resolve core attribute arguments, runtime setters, safely #291](https://github.com/perl11/cperl/issues/291)
* [feature/gh22-ffi branch](https://github.com/perl11/cperl/commits/feature/gh22-ffi)

# Comments on [/r/cperl](https://www.reddit.com/r/cperl/comments/6dmzkg/attribute_arguments/)
