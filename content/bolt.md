+++
date = "2018-10-22"
title = "Link-time and post-link optimizations"
tags = [ "cperl" ]
+++

I've tried several traditional linker optimizations on cperl recently.
The easiest is

# LTO

via `gcc -flto=4` or `clang -flto=thin`. This requires the gold linker, and 
enables multi-threaded link-time optimizations.

For gcc my configure script does

    CC=${CC:-ccache gcc}
    ./Configure -sder -Dcc="$CC" \
      -Dld="$CC -fuse-linker-plugin" \
      -Accflags="-flto=4 -fuse-ld=gold -msse4.2 -march=native" ...

and for clang

    CC=${CC:-ccache clang-7}
    ./Configure -sder -Dcc="$CC" \
      -Dranlib=llvm-ranlib-7 -Dar=llvm-ar-7 -Dfull_ar=/usr/bin/llvm-ar-7 \
      -Accflags="-DLTO -flto=thin -msse4.2 -march=native" ...
      
The impact is about 10%.

# AutoFDO

[AutoFDO](https://gcc.gnu.org/wiki/AutoFDO) is the optimized profile guided optimization
method on linux via perf, in opposite to `-pg` without `perf`.

On most recent kernels you need to recompile [autofdo](https://github.com/google/autofdo) by yourself

    git clone --recursive https://github.com/google/autofdo
    cd autofdo
    aclocal -I .; autoheader; autoconf; automake --add-missing -c
    ./configure --with-llvm=/usr/bin/llvm-config-7
    make -s
    make -s install

The perl/cperl Makefile already contains two targets for gcc: `miniperl.autofdo`
and `perl.autofdo`. For clang just replace `create_gcov` with `create_llvm_gcov`.
The `perl.autofdo` target just optimizes a static `perl` executable, not the shared
`libperl.so`, so beware. miniperl is always static, so you can measure the impact there easier.
For me it's about 20%.

The old method was the profile-guided optimization as described in the
gcc manual, also with a gcov file.

# BOLT

[llvm-bolt](https://github.com/facebookincubator/BOLT) is a bit similar to [prelink](https://community.linuxmint.com/tutorial/view/473)
from libreoffice. It's a post-link optimizer.
It analyzes perf traces from a running executable or service, and then rewrites the binary 
to be faster.

I've compiled bolt at `/usr/src/llvm/llvm-bolt/build`, added the bin path to my PATH
`export PATH=/usr/src/llvm/llvm-bolt/build/bin:$PATH`, added the `-Wl,-q` flag to ldflags
and lddlflags:

    sed -i -e"s,ldflags=',ldflags='-Wl,-q ," config.sh
    sed -i -e"s,lddlflags=',lddlflags='-Wl,-q ," config.sh

Before: `perf stat -r2 ./minibench.sh`, where `minibench.sh` is the script created by `miniperl.autofdo`.

Using bolt:

    perf record -e cycles:u -j any,u -o bolt.data -- ./minibench.sh
    perf2bolt -p bolt.data -o bolt.fdata miniperl
    llvm-bolt miniperl -o miniperl.bolt -data=bolt.fdata -reorder-blocks=cache+ 
      -reorder-functions=hfsort+ -split-functions=3 -split-all-cold -split-eh -dyno-stats

=>

    BOLT-INFO: Target architecture: x86_64
    BOLT-INFO: first alloc address is 0x400000
    BOLT-INFO: creating new program header table at address 0x800000, offset 0x400000
    BOLT-INFO: enabling relocation mode
    BOLT-INFO: 640 functions out of 1602 simple functions (40.0%) have non-empty execution profile.
    BOLT-INFO: 60 non-simple function(s) have profile.
    BOLT-INFO: profile for 1 objects was ignored
    BOLT-INFO: the input contains 702 (dynamic count : 1471) missed opportunities for macro-fusion
               optimization. Will fix instances on a hot path.
    BOLT-INFO: removed 2 'repz' prefixes with estimated execution count of 0 times.
    BOLT-INFO: basic block reordering modified layout of 589 (32.05%) functions
    BOLT-INFO: UCE removed 0 blocks and 0 bytes of code.
    BOLT-INFO: running hfsort+ for 642 functions
    BOLT-INFO: program-wide dynostats after all optimizations before SCTC and FOP:

              195150 : executed forward branches
               74347 : taken forward branches
               30966 : executed backward branches
               20082 : taken backward branches
               29596 : executed unconditional branches
               32611 : all function calls
                9659 : indirect calls
                5177 : PLT calls
             1501423 : executed instructions
              401528 : executed load instructions
              235761 : executed store instructions
                7071 : taken jump table branches
              255712 : total branches
              124025 : taken branches
              131687 : non-taken conditional branches
               94429 : taken conditional branches
              226116 : all conditional branches

              185751 : executed forward branches (-4.8%)
               13694 : taken forward branches (-81.6%)
               40365 : executed backward branches (+30.4%)
               20453 : taken backward branches (+1.8%)
               10158 : executed unconditional branches (-65.7%)
               32611 : all function calls (=)
                9659 : indirect calls (=)
                5177 : PLT calls (=)
             1478793 : executed instructions (-1.5%)
              401528 : executed load instructions (=)
              235761 : executed store instructions (=)
                7071 : taken jump table branches (=)
              236274 : total branches (-7.6%)
               44305 : taken branches (-64.3%)
              191969 : non-taken conditional branches (+45.8%)
               34147 : taken conditional branches (-63.8%)
              226116 : all conditional branches (=)

    BOLT-INFO: SCTC: patched 27 tail calls (27 forward)
    tail calls (0 backward) from a total of 27 while removing 0 double jumps and removing
    14 basic blocks totalling 70 bytes of code. CTCs total execution count is 2 and the
    number of times CTCs are taken is 0.
    BOLT-INFO: setting _end to 0xe040b8


After: `perf stat -r2 ./minibench.sh`

=> 

    # before bolt
    # started on Mon Oct 22 17:53:16 2018


     Performance counter stats for './minibench.sh' (2 runs):

       3538.885152      task-clock (msec)         #    0.777 CPUs utilized            ( +-  0.07% )
             2,024      context-switches          #    0.572 K/sec                    ( +-  0.47% )
               301      cpu-migrations            #    0.085 K/sec                    ( +-  5.65% )
           278,208      page-faults               #    0.079 M/sec                    ( +-  0.00% )
    10,721,866,060      cycles                    #    3.030 GHz                      ( +-  0.06% )
     5,875,656,960      stalled-cycles-frontend   #   54.80% frontend cycles idle     ( +-  0.10% )
     4,442,046,984      stalled-cycles-backend    #   41.43% backend cycles idle      ( +-  0.09% )
    10,623,986,253      instructions              #    0.99  insn per cycle         
                                                  #    0.55  stalled cycles per insn  ( +-  0.00% )
     2,225,877,429      branches                  #  628.977 M/sec                    ( +-  0.00% )
        86,592,270      branch-misses             #    3.89% of all branches          ( +-  0.07% )

           4.55333 +- 0.00405 seconds time elapsed  ( +-  0.09% )

    # after bolt
    # started on Mon Oct 22 17:55:46 2018

    Performance counter stats for './minibench.sh' (2 runs):

       3167.229126      task-clock (msec)         #    0.757 CPUs utilized            ( +-  0.12% )
             2,006      context-switches          #    0.633 K/sec                    ( +-  0.42% )
               293      cpu-migrations            #    0.093 K/sec                    ( +-  3.75% )
           279,450      page-faults               #    0.088 M/sec                    ( +-  0.03% )
     9,566,795,439      cycles                    #    3.021 GHz                      ( +-  0.00% )
     4,770,308,584      stalled-cycles-frontend   #   49.86% frontend cycles idle     ( +-  0.04% )
     3,558,581,947      stalled-cycles-backend    #   37.20% backend cycles idle      ( +-  0.01% )
    10,580,856,372      instructions              #    1.11  insn per cycle         
                                                  #    0.45  stalled cycles per insn  ( +-  0.03% )
     2,143,510,267      branches                  #  676.778 M/sec                    ( +-  0.04% )
        92,102,204      branch-misses             #    4.30% of all branches          ( +-  0.06% )

           4.18226 +- 0.00375 seconds time elapsed  ( +-  0.09% )

Which is an impact of 9% on the already link-time optimized executable. Nice!

`prelink` would also gain a lot of startup overhead, but is a bit
fragile, as every system update on any shared library would break it.

# Static linker optimizations

Now you ask how to get all the linker optimizations into the source
code and build-environment, to avoid all these compiler and linker
optimizations.

The first problem is to add missing or wrong `LIKELY`/`UNLIKELY` hints
to the branches in the sources.  I'm not aware of any automatic tool
yet, which can display the location of the data or gcov file of a
branch-hit or miss. But the source code is pretty good annotated
already. perf itself gives a few hints in its UI.

The next problem is how to get the LTO optimizations into the
Makefiles. We don't need a linker script, re-arranging the order of
the objects or just appending all sources into one big C file and
compile only this would accomplish this. perl is a bit large, the
compiler would consume too much memory, so I went for the optimization
of the objects at first.

There are two problem: permutate the objects itself, and second
rearrange the functions inside the objects.  Measuring all
permutations of the 38 objects would need several years, perl cannot
even represent the number as 64bit integer for a loop counter. So I've
tried a guided search on most permutations, from back to forth, and
stop subsequent permutations at the back when the generated file is slower
than before.  Something like this:

    my @o = glob <*.o>;
    my $best;
    compile(\@o);
    my $curr = bench($i);
    $best = $curr;
    my $p = $#o;
    for my $i (0..5000) {
      $p = permute(\@o, $p, $curr);
    };

    sub permute {
      my ($a,$p,$curr) = @_;
      my @idx = 0..$#{$a};
      my $new = $curr;
      while ($new <= $curr) { # faster?
        $curr = $new;
        --$p while $idx[$p-1] > $idx[$p];
        my $q = $p or return $p;
        push @idx, reverse splice @idx, $p;
        ++$q while $idx[$p-1] > $idx[$q];
        @idx[$p-1,$q] = @idx[$q,$p-1];
        my $tmp = $a->[$p-1];
        $a->[$p-1] = $a->[$q];
        $a->[$q] = $tmp;
    
        compile($a);
        $new = bench($i);
        print "# ",join(" ",map{substr($_,0,-2)} @$a),"\n";
      }
      $p
    }

    sub compile {
      my @o = @{$_[0]};
      if ($^O eq 'linux') {
        system("gcc -fstack-protector -L/usr/local/lib -L/opt/local/lib ".
               "-o miniperl @o -lpthread -lnsl -ldl -lm -lcrypt -lutil -lc");
      } elsif ($^O eq 'darwin') {
        system("cc -mmacosx-version-min=10.11 -fstack-protector -L/usr/local/lib ".
               "-L/opt/local/lib -force_flat_namespace -o miniperl @o -lpthread -ldl -lm -lutil -lc");
      }
    }
    
    sub bench {
      my ($i) = @_;
      system("./miniperl t/opbasic/arith.t >/dev/null 2>/dev/null"); # warmup
      my $t0 = [gettimeofday];
      system("./minibench.sh");
      my $elapsed = tv_interval ( $t0 );
      print "$i $elapsed\n";
      if ($elapsed < $best) {
        $best = $elapsed;
        print "# RECORD:\n";
      }
      $elapsed
    }

This revealed that the current object layout is suboptimal, several
miniperl-specific objects need to be spliced into the common_objs.

The best order on linux was:

    gv | perlmini miniperlmain | perly toke | opmini | av pad sv hv pp_hot run
    pp_ctl pp_type | ppmini | scope pp_sys regcomp mg doop util doio keywords
    | xsutilsmini | utf8 regexec universal perlapi globals perlio pp_sort pp_pack
    numeric reentr mathoms locale dquote mro_core taint time64 caretx dump deb
    
The old order was:

    miniperlmain opmini perlmini xsutilsmini ppmini |
    gv toke perly pad regcomp dump util mg reentr mro_core keywords
    hv av run pp_hot sv pp_type scope pp_ctl pp_sys
    doop doio regexec utf8 taint deb universal globals perlio perlapi
    numeric mathoms locale pp_pack pp_sort caretx dquote time64

You see the pattern: The earliest and most important objects start at
first, gv being the slowest and mostly used part, then the startup,
the parser, the compiler, the data, then the run-time and at last the
helpers.  Nearby functions are called faster, static relative offsets
can be shorter.  Note that cperl seperated xsutils and pp also into
*mini* parts because of the FFI.

The performance of the various orders varied wildly: from 3.031298s
to 3.990619s, i.e. +-31%.
See https://gist.github.com/rurban/67cb4b4046a3538837b6c2aade18ba2f for the
script and result log.

Relevant are also the size of the environment for a proper stack
alignment, we cannot control that. It's over the 2% noise rate though.
"Producing Wrong Data Without Doing Anything Obviously Wrong!"
https://www.seas.upenn.edu/~cis501/papers/producing-wrong-data.pdf has more
info about that. It also discusses why sometimes -O2 was faster than -O3.

Liska's "Optimizing large applications" https://arxiv.org/pdf/1403.6997.pdf
has also a good overview.

# Comments on [/r/cperl](https://www.reddit.com/r/cperl/).
