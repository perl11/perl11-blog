+++
date = "2017-03-03"
title = "cperl objects"
draft = true
tags = [ "cperl", "oo" ]
+++

cperl objects created from the new classes and also from the old
cperl-enhanced base/fields modules are tagged with a new flag to
allow more efficient field lookup. methods and method combinations are
looked up via their classes still, cperl has no class objects yet,
just old stashes with a HvCLASS flag.

