+++
date = "2017-01-24"
title = "p5p incompetence"
tags = [ "p5p" ]
+++

So I was continously asked to explain why I call p5p too incompetent to
design anything for the perl5 language and any internal VM features.

So far I was reluctant to do so, because users will be as emberrassed as I
am, and need a way to got forward. Now that I can offer a way forward it
might be easier to publish the detailed criticsm on p5p's incompetence.

From a high level view it's pretty easy to prove.  p5p, the perl5
porters was originally a mailing list to help Larry Wall, the language
creator to maintain ports to other platforms. like solaris, hpux,
irix, os/2, windows and so on. That's why it's called porters, and not
perl5-dev, perl5-lang or something.
Then, when Larry Wall stopped maintaining perl5 and went on to perl6, p5p
took over maintainance of perl5 from him.
Let's roughly say p5p started 2001 and hopefully will be freed from maintaining
the language and the vm 2016, 15 years.

In these 15 years p5p did almost nothing good, and a lot of things very bad.

# let's start with the good things:

- lang:
  - adoption of perl6 `say`
  - design and implementation of dor `//` (defined-or)

- vm:
  - direct access to sv bodies, and sv arenas
  - op arenas
  - multideref
  - cleanup of CX, the context stack

say is trivial, but with proper 5.005 threads even then wrong, as was
seen in parrot.

defined-or is trivial, but the discussion about the syntax was so
painful, that Tom Christianson left p5p over that, which got Larry
very angry. and '//' for defined-or and not something with matching is
also very ill-designed. That's the only new syntax since decades.

The 5.10 rearchitecture by one person was still 10% slower than 5.8.9,
(only startup time got faster)
And broke many important internal B modules, like the compiler, the
type checkers and optimizers, B::Generate, ...

The rest was great work, esp. the context cleanup.

# neutral:

## proper implementation of given/when and smartmatch from perl6

given/when was plagued by an initial bug in the optimization of lexical `$_`
2001, mixing up a bitcheck, which initially worked by chance, but was later
broken in op redesign. They never found the bug, and decided mark it as
'experimental', i.e. broken.
Now without working lexical `$_` it is doomed. A run-time matcher makes not much
sense. What it needs are compile-time optimizations. Most matches can already
perform before.

smartmatch was always plagued by the lack of coretypes and the subsequent
over-architecturing of the possible lhs-rhs match combinations.
without working lexical `$_` it is also doomed.

Note that p5p didn't implement given/when and smartmatch, it came from
outside.  That's why they have so many problems to maintain it.

# bad:

- removed automatic compile-time optimizations in constant-folder
- no adoption of the initially designed type system
- no object system: no class/method, use oo :final, multi-dispatch, method-combinations
- incompetence maintaining pseudo-hashes
- horrible over-architecturing everything damian conway did
- horrible implementation of switch, based on source filters
- incompetence maintaining native threads (5005threads)
- incompetence maintaining the compiler
- incompetence maintaining B
- lack of understanding of basic data types
  - scalar
  - array
  - hash
  - regex
  - function
  - methods
  - symbols
  - binary symbols and names
- lack of understanding of basic vm techniques
- no plan
- signatures
- modules
- death by code of conduct
- security

# In detail:

## removed automatic compile-time op optimizations in constant-folder

One special guy with big personality problems removed that by himself,
against the explicit analysis of the community.
Now perl5 has the semantic problem that obvious constant values cannot
be treated as constants. cperl fixed that by going back to the pre-p5p semantics
(5.005), but that's the only major mismatch. It is only a problem with integer
overflows.

## no adoption of the initially designed type system

perl6 has one, cperl has one, everyone is happy, just p5p bitches
about it. "Only over our dead bodies."
Now after a few years even all other dynamic languages implemented it
only p5p is still clueless.

## no adoption of class/method, use oo :final, multi-dispatch

perl5 has an extremely slow OO system, without any features.  It can
be extended, but then it's even 10x slower. There's no internal
support for the needed features. Those features were designed 15 years
ago, so there's no need for external experimentation.  Moose is a
horrible abomination of those features and syntax. Spiffy, Mouse or
Dios do come closer but it's still a long stretch to a useful OO
system.

Everybody is talking about the need of a MOP, but nobody knows what a
OO vs MOP is. What is needed is an OO with introspection, but not a
MOP. What is needed is a way to make field access and dispatch
performant, and finalization.

## incompetence maintaining pseudo-hashes

The current narrative is that is was an enourmous failure, and
completely wrong.  The failure was one little part during
implemention, when one innocent guy stepped up and said, why cannot we
have support for this (tie) also? and then this was supported also,
and then performance and design went downhill. If you ask p5p, they
have no idea what went wrong and why. The party line is that the
whole idea was a desaster, not just their maintainance failure along
the line.

pseudo-hashes were a neat trick to support compile-time plus run-time
fields in an efficient and introspective way. Of course in the
non-perl world the compiler should have changed hash-like access of
compile-time known members to linear lookup in array fields, and not
expose the hashes as pseduo-hashes to the user at all. Run-time
computed fields would still use a hash table as in a cache or linear
search through the fields. `$obj->field` vs `$obj->$field` as in
method dispatch or `$obj->{field}` vs `$obj->{$field}`. perl6
thanksfull got away with the latter hash syntax and exposes all its
fields as members in a method-like syntax. And there are syntactic
designators for visibility and read/write accessors. This way the user
cannot create clashes between methods and fields as all fields are
exposed as methods, and the compilers knows what is what.

Marc Jason Dominus explains at the [Pittburgh Perl Workshp 2014](https://www.youtube.com/watch?v=-HlGQtAuZuY)
how the perl community is not able to understand it why their attempt
to maintain this feature utterly failed. "A new, never-before-seen
talk on Perl's catastrophic experiment with “pseudohashes”, which
wasted everyone's time for nine years between 1998 and 2007." His
words, not mine.

## horrible over-architecturing everything damian conway did

Thanksfully not much of him is in core.

Attributes are unusable because of him, the implementation is not as bad as
a usual conway implementation (good in theory, but naive and impractical),
even all the documentation improvement attempts were rejected by p5p.  The
fast XS implementation was replaced by a worse and slower PP implemantation,
Attribute::Handlers which is in core, is insecure by default, it evals all
its attribute values. e.g. with `App::Rad`
`sub unlink :Help(unlink "a/file");` as documentation
attribute will call `unlink "a/file"` at compile-time.

## horrible implementation of switch, based on source filters

This Filter hack is still in core.

## incompetence maintaining native threads

Agreed, using 5005threads requires knowledge of concurrency, needs locking
in many XS extensions and esp. a concurrent hash table.  This was not state
of the art those times.

But the pseudo threads (ithreads) should not have been called threads.
there's no proper COW support, all the data needs to be be cloned to each
new thread, so you got a huge initialization hit. And the run-time supports
no ownership or capabilities, so all the data needs to linked back and forth
manually.

Forking does this properly, so you need to use fork. ithreads are only an
overly slow fork emulation for windows.

## incompetence maintaining the compiler

With the data layout changes for 5.10 they removed all the compilers, and
dropped support for basically all compile-time extensions with its B module
hierarchy, the introspection framework.
All the type checkers, optimizers, compilers were gone.
All the people working on compile-time optimizations left to better languages.

It is surprising because the three B compilers are much simplier to understand
and to maintain than the core VM.  But it is not so surprising when you
realize that they have also no idea how the VM works and should work.
All the people you have an idea went on, or switched to perl6, were the most
egregious perl5 design mistakes were solved.

## incompetence maintaining B

Since the B instrospection module needs to able to represent all the
internal core data structures to pure-perl users, but only the simpliest B
modules were left intact with the 5.10 axe, it's hardly surprising that B
started bitrotting. nobody cared anymore, it was only used for the
B::Deparse toy, which never worked 100%, and B::Concise, a simple display of
the ops.

The destruction happened gradually, but the real problem was that eventual
breakage was not undone, with the argumention that "p5p does not understand
how this works, and how we broke it.  go away".  They outright refused to
fix it for years and it is still broken.  I have to maintain my own version
of B, which you need for any compiler.

## lack of understanding of basic data types 

perl5 lacks the most basic performance features of all the existing data
types. This were mostly Larry Wall mistakes, and he could have looked up how
other languages did it those times.

My point here is that even after 20 years nobody within perl5 has any idea
how to improve it, even if now everybody else found put. Even php7 put perl5
to shame. perl6 on the contrary knows about it.

# scalar:

In a normal dynamic language a scalar consists of the three basic
types int, float and string, plus refs, and sometimes booleans and
null.  Those basic types are usually implemented either as fast
primitives, using only one or two stack slots, such as e.g. lisp
fixint, doubles with nan-tagging, null, booleans and the big scalars
on the heap.  refs can contain a class pointer to create
"objects". Anything can be an object. In common lisp e.g. those
primitives contain two stack slots, the class and the tagged primitive
values.  A function is everywhere a big scalar.

In perl5 there are no unboxed values on the stack, there is not even a stack.
Not for arguments and return values, not for lexicals and temporaries.
the normal design problem in a computer language how to find "upvalues",
lexicals which are not temporaries on the stack, but rather are closed over
on stacks of upper functions. In perl5 this was simplified by using "pad's",
seperate flat arrays with indices or usable and reachable ranges. This is
quite ok, but accessing a stack entry is still 50x faster.
And mosty writing a temporary or lexical is very slow in perl5, as you
cannot overwite just the single or double stack values, you need to change
4-10 slots on the heap, esp. keep track of refcounting. Remember why php7
is 2x faster? Smaller data and they got rid of unneccessary refcounting.

The cow hack for strings is not only totally unacceptable and slow. It
is also totally unmaintainable. I tried to fix and rewrite it two times
already.

# array:

In normal languages you provide fast access to array elements, per default
or optionally. Even lisp can do that.
In perl5 this is not possible. (well, it is in cperl and perl6, but p5p has
no idea about that).

First, every index can be negative to index it from the end.

Second, every single object can be tied.

Third, every single value in the array is a reference to somewhere
else on the heap. There are no natively typed arrays consisting only
of ints or doubles (primitives). Every access and update is not in
place, it involves the reference on the heap.

Forth, there are no optimizations to eliminate run-time bounds checks.
cperl and perl6 have shaped arrays.
Every self-respecting language supports bounds checks elimination.

Fifth: there are no overflow checks, indices silently overflow.

    $ perl -e'@a=(0,1);print $a[~1]'
    0

~1 is essentially (UV)-2 or 0xffff_fffe. It's the highest unsigned
positive value - 1, but here in this case it wraps around to -2. Which
is arguably wrong.  But this is different to that:

    $ perl -Dt -e'print $a[~1]'
    (-e:1)	const(IV(1))
    (-e:1)	complement
    
    EXECUTING...
    
    (-e:0)	enter
    (-e:0)	nextstate
    (-e:1)	pushmark
    (-e:1)	gv(main::a)
    (-e:1)	rv2av
    (-e:1)	const(IV(18446744073709551614))
    (-e:1)	aelem
    (-e:1)	print
    (-e:1)	leave

Yes, you see that right. It is creating an array with
18446744073709551614 elements, accesses the last element and returns
that undef value.
And now the best trick:

    perl -e'@a=(1);print $a[18446744073709551615]'
    => 1

Yes, you see that right. perl5 silently overflows the index to the
index 0 and returns its value. Same as above where ~1 silently
overflows to -2.  cperl fixed that btw. by throwing a compile-time
'Too many elements' error.  Silent wrapping on overflow is not a
language feature, it's a bug. Only p5p keeps up with the narrative
that this a feature as designed.

# hash:

There is no knowledge of hash tables within p5p. The first re-implemention
after a DoS attack with 5.8.1 made a grave optimization mistake, which I
did not do when I fixed the old 5.6 hashes. Then a similar mistake was
detected with 5.18 when the used hash function was not zero-invariant.
You could produce collisions by adding \0 anywhere.

There is no single hash table implementation out there in the open
public which is worse than perl5', and I looked around a lot. But the
friends of p5p convinced wikipedia that the perl5 hash table is a
specially well-made and heavily optimized version, because everything
in perl5 is done via hashtables. symbol tables, objects, maps. This is
exactly how p5p sees itself.

In reality not even the design is wrong, also the implementation.  The
simple slow linked list idea is horrible and is getting worse and
worse over the decades. The inner loop consists of 4 comparisons
instead of one. The pre- and post overhead is gigantic. They have no
idea about proper security and came up with hotch-potch ideas to slow
it down. Which is interesting because the guy who decided to break it
even more, works in the same company as a guy who knows about proper
hash table implementions a lot and does exactly this at this
company. Just in C++.

The collision resolution strategy is caused by fear and security
theatre, not rational thinking. Everybody else uses move-to-front,
perl uses randomized iterators and random flipping.  perl5 uses a 100%
fill rate, while testing a proper fillrate lead to better rates with
80-90% as everyone else. There's not even an option to try it,
and then using `_builtin_ctz` (count trailing zeros) to use it efficiently.

Rewriting the horrible hash tables to a proper open chained cache
friendly variant would be a very nice to have, but since the p5p
refactoring made it so bad, it's a really hard job to do now.  There
four different hash searches around, three different hash table
element types. There's no abstraction, so many external XS modules
have to access internals looping through the collisions.  It would
have been trivial with Larry's old hash tables.
I needed essentially half a year just to abstract away all the
existing cruft, to be able to try out the usual hash table
variants. So better hash tables are not in v5.26c.

Marc Jason Dominus gives a trivial explanation of perl chaining vs
python's linear addressing 2015 at
[https://www.youtube.com/watch?v=u14GpzuTBjg](https://www.youtube.com/watch?v=u14GpzuTBjg)
but cannot explain performance benefits, how and why perl tombstones
are needed (he says only python needs it), nor explain any modern hash
table or security issues with the collision chaining. Nor does his
talk explain the various important historic errors porters did from
5.6 to 5.18, regarding ordering, random seeding vs uniform hashing,
wrong optimizations. Nor does he mention the recent python and ruby
2.4 hash table refactors, which do address all these issues.  Porters
themselves cannot even understand open addressing, let alone basic hash
table security and performance.

Then hash keys: Hash keys are silently capped at I32_MAX, without any
warning or error. Longer keys are silently accepted and hashed, but
the hash is wrong because the length silently overflows and the key is
wrong because it is too short. Technically you could accept longer
keys and turn them into SV's, but even this is not done.
This is not a policy, this is pure incompetence.
cperl errors with overlong names/hash keys.

# regex:

The regex compiler is a hack and is unmaintainable. It is the old
Henry Spencer compiler code from 1988, where logic branches are done with
`setjmp`/`longjmp`, where the regex is parsed twice, but the result of the
first parse is not used to switch to a better compilation and
run-time, as critized by Russ Cox decades ago, leading to **re2**,
with a linear run-time without backtracking.

The problem of backtracking stack exhaustion was not fixed by
switching the compiler, and using the 2 pass information. Rather the
simple and maintainable recursion code was rewritten into iteration,
leading to even worse and slower code. There's still no stack limit.
So the small stack limit is now replaced by the larger heap limit,
leading to even nicer and more effective DOS attacks. davem's rewrite
didn't make it safer, but worse and 10% slower. He's still proud of
it though.

There's no sign of taking over libpcre, which has a jit in the
mean time, and add the missing unicode name support there. The libpcre
maintainers are clearly more competent than p5p and this might have
led to undesirable discussions.
Note that the p5p regex maintainers have no idea what I'm talking
about here. They also ridiculed Russ Cox when he complained and
offered improvements. What they did then was the policital correct
idea, to offer an API for alternative implementations because they
were not able to fix their own. This did not help at all.

# functions:

How perl5 calls a function is horrible, first because of the primitive initial
design with custom stacks and pads. The ability to localize and throw from
everywhere (there's no compile time detection and optimization). The lack of
typed signatures, all the args and return values are copied to @_, and not
kept on the stack as with better XS interface.

# methods:

perl5 supports only single dispatch on the first argument. Improving
the other builtin ops, esp. binops but also generic ops works via
overloading them, i.e. runtime lookup if this method is overloaded.

There's no multiple dispatch as in perl6, and the usual strategy to
speed up such method calls is "PIC", polymorphic inline caching, which
might store a hash of all used classed per method to avoid costly
run-time lookups.  There came a patch from russia, which implemented
that quite efficiently, but p5p managed to simplify that down to a
naive monomorphic inline caching (only cache the latest), which is
what we have since with 5.22.  That's why it's suddenly 20% faster but
could have been 30%.

They never heard of that term, and it is better to avoid any technical
terms with them, as they they have no idea what you are talking about.
Their are mostly sysadmins with no CS background.  But they are very
happy to invent new terms for existing technologies under a different
name to avoid scrunity.  e.g. they call mixins "roles" and attributes "traits".

There's no method keyword, and the existing `:method` attribute bitrotted
because it is of no use. As signatures and an object system didn't make it
into perl5.

There is a lot of talking about a "Modern Perl" movement, using Moose and
signatures, but they have no idea what they are talking about.  Moose is a
post-modern naive and inefficient implementation of the perl6 object system
with a bit of CLOS, but without the cleaner perl6 syntax.  A "modern" system
would follow the "form follows function principle", it would be lean and
efficient.  But Moose is an enormous and naive hack without any proper core
support from within, and entire hodge podge of workarounds around the
impossibility within perl5 to store compile-time generated classes per
pointer. every class and method is being looked by name, and name lookup
is not efficient due to the inefficient hashes, it is also inefficient due
to the inefficient and naive design of the perl5 symbol tables. nested
hashes of hashes and not one flat hash table as symtab.
efficient lexical lookup is unheard of, p5p did never come to help. 
Lookup by pointer is impossible.

Mouse would be the "modern" and efficient variant of Moose and is
about 10x faster, but it still has to follow the awkward and unnatural
Moose syntax and not the tighter and more natural perl6 syntax.

# symbols:

I already mentioned the initial naive and slow implemenation as hash
of stashes (stash = symbol table hash). this also leads to surprising
language inconsistencies which initially was considered a language
quirks, which would be eventually fixed (and it would be quite trivial
to fix), but just this year p5p announced suddenly that it will never
be fixed. it's now part of the language.

I'm speaking of autovivification, the fact that when you ask if a symbol or
stash exists, it does not exist, but all intermediate stashes in the
namespace get magically polluted by that query, and a query to a previously
not existing stash will now return yes. it's a parser bug with the namespace
lookup, which will be fixed with cperl and is fixed in perl6. but p5p
decided that such a bug is now a feature. action at a distance is a language
feature, because perl is magic and dynamic.
in my opinion it's only caused by gross p5p incompetence, not even knowing
the history of perl5 anymore. this bug was always considered a bug.

see also unicode security below.

# binary symbols and names:

For 5.16 a google summer of code student wanted to improve the support
for unicode names, symbols and packages. UTF8 was already supported
since 5.8.4 with a negative length in a HEK (hash key), where names
are stored. But the external API was lacking a bit.

But what eventually went into 5.16 without any public notice was
support for binary names, names which include \0. This is not a valid
unicode character and this broke many previous sound
assumptions. First, we had a way to hide some symbols behind a \0, and
there was one which was used that way. This was now broken.  Second
and more important are the security aspects. The external API via
syscalls using names and files does not accept those names. You can
declare different packages mapping to the same file being loaded from
disc. Over and over.  You can hide anything behind symbol and packages
names, and nobody will find out, because everything behind the \0 is
ignored, when using external API calls. This was quite a problematic
change, which nobody knows about because it was never announced, and
even the current maintainer does not know about it. He gave a XS
primer talk at a YAPC explaining how easy it is to work with XS, but
he still used the old wrong API without support for binary names.
Until this day, 10 years after, there are no PPPort macros to support
binary names with old XS code.  The p5p argument for this was: "we
sanified the API, it is now consistent".  Which means that all `gv_*`
calls broke and needed a new version with an extra len argument just
to support binary names.

Technically binary names to support any junk for readable names is
very problematic regarding
[TR39](http://websec.github.io/unicode-security-guide/), the handling
of confusables, mixed scripts and syntax spoofs. In perl5 it is easy
to hide malicious unicode code in source code, i.e. hiding in hidden
right-to-left sequences or hiding different names with similar looking
characters, and there's no confusables check in the parser, something
like `use strict 'names'` to accept only parsable names without
accepting confusables. cperl fixed a couple of major unicode security
issues since and follows the unicode security profiles for identifiers.
Apparently it is the first and only language implementation which does so.

And the second problem is the unfortunate layout of the
global symbol table as nested hash of hashes ("stashes" - symbol table
hash). Every lookup in a longer package name, not using a lexical
variable or function or method call needs to look the name in a series
of nested hashes, and not just in one global symbol tables, as in all
other dynamic languages. Now with full support for binary names
(i.e. any junk) the flood gates are open, and optimized variants for
symtabs are not usable anymore.

perlcperl.pod has this section:
"Check converting the GV stash tree of hashes into a single global data
structure, not a nested hash of hashes: Hash, AVL tree, Trie (TST or
R² TST), Patricia trie or DAFSA (Deterministic acyclic finite state
automaton) for faster dynamic variable and function name lookup. No
binary names, all as UTF8. Maybe restrict to ASCII or valid
identifiers to limit the trie memory (array of 26 vs 256).  Stashes
point then to trie nodes and need a HV check.  Optionally provide
partial read-only support for the compiler, as for `PL_strtab`.

Of course p5p is not aware of any unicode or binary name problems,
optimization possibilities or alternative implementations. The only
other one who complained was Tom Christianson; about right-lo-left
problems (bidi spoofs).

# lack of understanding of basic vm techniques

The VM, the runtime part of the interpreter, is still a nightmare.  It
would be easy if anybody would actually listen to someone who has an
idea, like e.g. Larry himself.

We carry around way too much bloat in the ops and the data, which is
not needed at run-time. e.g. the compiler throws away the nested
symbol table stashes if not needed, which frees 20% memory.
But think of a lua/p2-like redesign of tagged values and slimmer ops,
and eventually put the stack onto the CPU stack.

Note that p5p argues the opposite way. They want to add even more
run-time branches to the ops, without any justification.

perl5 has no proper stack. their stack is on the heap. which is 50x
slower to access and needs manual destruction. destruction on the
stack is free. the stack is also not refcounted.

perl needs to optimize special arithmetic op sequences to use unboxed
integers and strings on the stack. There's a reason why in normal
languages short lived variables are kept on the stack and not on the
heap. Why values can easily be updated.  cperl does experiment in
allowing unboxed values on the stack, because the stack is not garbage
collected and not refcounted.  Same as in perl6. We just need to be
sure to box them before entering a non-collaborating sub, leaving a
block with possible exceptions and stack cleanup. Those unboxed values
are internally typed as `int` and `str`.  Note that the coretypes
`int` and `str` are not guaranteed to be unboxed, only if the compiler
sees fit, same as in perl6. In most cases those values are boxed but
without a class pointer and magic attached.

Maybe rewrite to a better register-based compiler with fixed-length 2
operands as in p2, but this might be too tricky for XS, mapping the
global stack to the local stack.  Probably no SSA (three arguments),
just a cpu friendly two argument form as in p2/lua 5.1.

Allow faster XS calls, user-provided function calls and method calls.
Provide support for named arguments in the vm, fast not via hashes.
Many of the current io+sys ops are better implemented as library
methods.  With ~50ops instead of >300 the runloop might fit into the
L1 cache again.  Seperate calling of fixed arity methods from varargs.
detect and use tailcalls automatically.  Do not step into a seperate
runloop for every single function call, only for coros, which do need
to record the the stack information.

Run-time optimize the data, no 2x indirection to access hash and array
structs. Provide forwarding pointers to single tuples to hold all.
This could provide also the possibility for a GC if a second sweep
for timely destruction is doable.

# no plan

p5p lacks a proper todo list, just a small pathetic collection of
useless and tiny ideas in `Porting/todo.pod`. Nothing came ever out of
it. Larry had a proper todo long time ago, but p5p deleted it since,
to avoid looking too bad.
They have no idea what to do, what to improve and how to go
forward. For example some years ago I mentioned the simple idea to
seperate XS and PP function call ops.  I implemented it easily in a
few days with a 10% gain, but they deleted it from their todo list as
not worthwhile ("entersub XS vs Perl" db1070bec96) and they removed
the official man page of perltodo.pod.

Their feature discussions and design is not working.  Larry had a
proper todo list in the very old days, including sound and worthwhile
goals, like a ffi, types, signatures, an object system. But this was
deleted by p5p in the early years.

Their big ideas consists of: "make ithreads more robust". Yes, that is
all.

# signatures

signatures should have been added to core for 15 years. proper
external implementations do exist. they are properly designed in
perl6, there are no design problems, just lack of knowledge how to do
it.

The first attempt was adhoc, simply splicing the optree into the
function.  At least this version had proper callbacks for
introspection. But the discussion about this attempt was pure
bikeshedding, nothing came out of it, and in the end it was not
done. Explicit attempts to help and improve it were ignored. The
second attempt (*purple*) was by a core committer, and was technically even
worse. For example the arity check was twice as slow as necessary, the
implementation two times slower than not using signatures at all, most
of the signatures features were missing. These purple signatures went in
because it was by a committer, even when the design had grave mistakes.
The next attempt also by a core committer was a bit faster and used
the same trick as with the multideref optimization. but internally it
was still lacking proper design, it still copied all values to the
magic `@_` array and was thereby still slower than not using
signatures. And no features being used in perl6 and all other external
CPAN implementations were added.  no types, no self invocant keyword,
named args, ...
Esp. types are crucial for a modern perl, but switching to the XS api
with the arguments on the stack would have also been crucial. Which is
esp. interesting since cperl already had a proper signature
implementation which was 40% faster than not using signatures, and
many compile-time checks improve code quality and readability.

# modules

My [blog.perl.org](http://blogs.perl.org/users/rurban/2016/04/overview-of-current-maintainer-fails.html)
post lists all of the important modules maintenance failures as of
5.24.0, and p5p was the biggest part in it. There are no inaccuracies
in this post, since I personally fixed all of these problems by
myself, but I was blocked by the maintainers to respond to the
criticism there.

But there's much more. Rarely passes a p5p maintained module the basic
bullshit test.  Storable cannot deal with overlarge data and writes on
its stack. Unicode::UCD is as horrible as the internal unicode invlist
layout, using plain huge strings in files, which are split at runtime
to invlists, stored in SV's, and then binary searched. Which is 800%
slower and much larger than a normal pre-compiled data structure, as
it would have been done when a cpan author would have maintained
it. Such as e.g. Encode or Unicode::Normalize.  And this static
read-only and uniform data should be compiled to a shared library as
Encode does it.  strict, vars, warnings, Config, Exporter, DynaLoader,
XSLoader, B, re, Filter and many more are either in a horrible and
unacceptable state, or I stepped up and took it over. Basically the
only acceptable internal module is Win32CORE and CharClass::Matcher to
compile character class search to almost efficient .h code.

# Security

Not talking about that, since the security discussions were secret,
while certain members of that list brought my description how to hack
something, e.g. DBI to the public without fixing it. He fixed it
(applied y patch sitting in his queue) one year later eventually.  The
overall impression is that they are totally incompetent, and they
continue to be incompetent. With cperl alone I’m fixing 4 new security
problems per release, and only one of them ever made it into perl5
since.  When they announced 5.24.1 I had publicly listed 24 known
problems with 5.24.0, and they indented to fix none of them. After a
few months of waiting for that bugfix release they at least agreed to
fix a few of them, but make every effort not to cherry pick my
fixes. Active hostility and refusal to cooperate.

Just look at the many many security problems cperl has fixed
since. p5p only picked up one of it: `-Dfortify_inc` but even managed to
change it's API since then.

I warned against binary and unicode symbols since its invention with
5.16.  Nothing has happened since, only cperl made progress in
disallowing mixed scripts and normalizing identifiers.

# Death by code of conduct

The last maintainer had the idea to improve the discussion problems,
the constant angry and fruitless discussions, name calling and racist
remarks by a new code of conduct. It didn't help, instead it
backfired. Certain p5p members who still happily enjoy to break the
new code of conduct are not even warned about breaking any rule, they
still serve as public figure heads, give the main YAPC conference
talks and are allowed to call certain users assholes every year in the
conference keynote. For years. But the ones who technically critise p5p and try
to improve the lock-in were not only being called assholes and trolls,
they were even removed for breaking the unwritten but publicly emailed
rule of this COC, "that you should have faith in p5p". Which is
ridiculous given their track record.  By not having faith into these
maintainers you are not allowed to be member in this community, are
being blocked from posting to their blog, mailing list and access the
bugtracker. an outragiously broken community. After the fork they
became actively hostile and broke all communication.  But the code of
conduct served its goal, the community is now officially broken and
dead. And perl5 officially became a [religion](cperl-is-not-a-religion.html).

# Closing

The signatures desaster is one of the most apparent signs of the
collective and individual p5p incompetence. I would argue the
complete lack of any success in their whole 15 years of maintainance
is a bigger tellsign.

But we all can live with incompetence. We all know managers and do
work in companies, and we all know the peter principle. A bigger
problem than incompetence is being actually **destructive**. Within
p5p the key figures turned out to be not only incompetent and some of
them arrogant and unpleasant human beings, but actually destructive in
removing features when they are not able to maintain it anymore,
destroying performance, destroying the code base maintainability,
causing pain to cpan maintainers and generally doing and talking
nonsense. This is the main reason why I became active in protesting
these tendencies.

Most more competent people left the perl community silently years ago,
there's no talent anymore, that's why it's easy to come up with such
an incompetent group and maintain this status for 15 years.  And
sometimes, when there's fresh talent, and actually turned out to come
with better ideas and implementatioms those ideas don't make it into
the codebase. The dead wood is protecting its turf.

I offered solutions to fix those problems multiple times, and was
being shouted at.  The only thing helping now is to dissolve the perl5
porters from being the language maintainers committee, and just be the
porters. that's what they can do. Nothing else.  Immediately remove
commit access to the ones who are doing the ongoing damage.  There is
no need for them acting like a language committee since Larry and then
perl6 already did that, just ensure to keep backwards compatibility.

Ensure a working management. This is not solvable. Electing community
and people managers who should manage opposing opinions makes no
sense, since there will be no agreement, the manager has no idea what
they are talking about because he is the technically most incompetent
of all, and the existing devs showed no sign of competence and
managebility. Most features were brought in by bypassing processes
and management.

In cperl and perl6 we use public trackers and irc, no mailing-list.
Features and bugfixes are developed by proper process.

--
Reini Urban
