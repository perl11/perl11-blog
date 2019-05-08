+++
date = "2019-04-15"
title = "The perl5 Storable desaster"
draft = true
tags = [ "cperl", "security" ]
+++

Storable is one of the builtin perl5 serializers. It's one of the
complete serializers, like Data::Dumper or Sereal, unlike JSON or YAML
which can serialize only partial data. Serializer can serialize code and
all the datastructures with all internal flags.

Thus it is inherently insecure, as you should not deserialize external
coderefs or objects. Even deserializing normal datastructures such as
nested hashes or nested arrays may lead to stack overflows, as
Storable does the deserializing recursively and the perl5 call stack
is limited.  If an application accepts external serialized objects,
such as Storable frozen session cookies (like most PHP web
frameworks), it's open to desaster. This was e.g. the downfall of the
once-popular perl5 wiki Movable-Type with CVE-2015-1592, which
injected Object::MultiType and DateTime or Try::Tiny objects into the
session cookie, waited for its automatic destruction at end of scope,
and hereby triggering user-controlled methods. See
https://www.youtube.com/watch?v=Gzx6KlqiIZE for an explanation.

This was detected by cPanel 2015, and the security team there even
created a metasploit module for that, because the perl5 security team
was known to be apathic against such security-critical
attacks. Without that exploit code they would have just adjusted the
documentation and blamed the users. They still do. The perl5 team at
cPanel then decided to fix the serializers security bugs, and came up
with several solutions. For JSON we created Cpanel::JSON::XS with
default options to disallow blessed objects.

For Storable we first disabled blessed and tie, and allowed it only
with an additional option.

Then there were several overflow bugs for 64bit data. Exploits could
create huge datastructures (hashes, arrays or long strings), which
would overflow the 32-bit only deserialization methods. perl5 is still
not 64bit safe, there are many remaining 32bit overflows, which cPanel
only fixed only in its own variant cperl, but those fixes are still
ignored upstream.

Then there was the . in @INC problem we found and fixed, where an
attacker could drop a payload with the same name of an to be loaded
module in the current directory, and perl5 would pick that up, instead
of the default module. This was fixed in cperl 2 years before perl5.

Then there was the stackoverflow problem writing onto the perl stack.
E.g. you could easily find out the maximal stack depth for the to be
exploited perl version, and create a nested array like this: `$t =
[$t] for 1 .. MAX_DEPTH;`, and add your payload onto the stack.  perl
would not find out about that recursion overflow and would happily
call your payload. A small recursion limit is hardcoded into the the
JSON serializers, but Storable being the official serializer should
not impose low limits for nested datastructures which are fine to be
used inside perl5. So either the serializer needs to be rewritten
without recursion. But I decided to probe for the actual stack limit
at installation time and support nested datastructures up to that
limit. This MAX_DEPTH limit can quite high up to 20.000, so it would
allow 99.9% of all data and not impose serious limits, and it still
allows small and elegant recursive code.

TBD ...
