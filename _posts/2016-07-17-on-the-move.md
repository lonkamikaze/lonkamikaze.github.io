---
title: On The Move
news: 1
tags:
- meta
---
The transfer from [my Blogger page](http://angryswarm.blogspot.com)
is in progress. Because I'm manually converting content from HTML
to markdown, it takes its time. I haven't gotten far, but I updated
the article on
[suspend/resume with with full disk encryption]({% post_url 2014-04-01-geli-suspend-resume-with-full-disk-encryption %}).

I've split the articles into news and journal entries, and the old
articles only contain one post that counts as news. News really are
just everything that I don't deem worthy of the term article.

The page design isn't finished either. I left some space in the left
and right that is supposed to be filled with meta content. But I'll
leave that to last. This stuff is optional any way --- as space for
the page gets more narrow, the side bars disappear and the header
gets more compact.

This is mostly for the sake of mobile devices. I've had weird effects
on Android/Chrome where portrait mode was weird. Fonts were mixed
small and large and the CSS thought it had more space than it actually
did. Firefox on Android just pretended that portrait mode was the
same width as landscape mode and displayed everything unbearably
tiny. Some googling of the issue revealed that there is a meta tag
that makes browsers not lie about that stuff:

~~~ html
<meta name="viewport" content="width=device-width, initial-scale=1" />
~~~
Make mobile browsers do the right thing.

And suddenly things started working the way I expected. Hurray!
