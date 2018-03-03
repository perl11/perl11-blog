#!/bin/sh
cd ~/Documents/perl11-blog/
hugo

echo /usr/src/perl/blead/perl11.github.com/blog/
cd /usr/src/perl/blead/perl11.github.com/blog/
rsync -avz ~/Documents/perl11-blog/public/* .
git status
echo "cd /usr/src/perl/blead/perl11.github.com/; git status"
