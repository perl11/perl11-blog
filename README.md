Install hugo  https://gohugo.io/overview/installing/

Add content in `content/` as markdown.

Preview with `hugo server` or `hugo server -w -D` including drafts.

Publish with

    rm -rf public/*
    hugo
    rsync public/* ../perl11.github.io/blog/
