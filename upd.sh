#!/bin/sh
cd ~/Documents/perl11-blog/
hugo
sed -i 's,"/page,"/blog/page,' public/*.html

echo /usr/src/perl/blead/perl11.github.com/blog/
cd /usr/src/perl/blead/perl11.github.com/blog/
rsync -avz ~/Documents/perl11-blog/public/* .
git status
echo "cd /usr/src/perl/blead/perl11.github.com/; git status"
