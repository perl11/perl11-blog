#!/bin/sh
cd ~/Documents/perl11-blog/
hugo
#broken with 0.20, fixed in 0.59
#sed -i 's,"/page,"/blog/page,' public/*.html

echo /usr/src/perl/blead/perl11.github.io/blog/
cd /usr/src/perl/blead/perl11.github.io/blog/
rsync -avz ~/Documents/perl11-blog/public/* .
git status
echo "cd /usr/src/perl/blead/perl11.github.io/; git status"
