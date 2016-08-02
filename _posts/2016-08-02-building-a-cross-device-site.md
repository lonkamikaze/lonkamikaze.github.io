---
title: Building a Cross Device Site
journal: 1
tags:
- web-design
- compatibility
- performance
---

This isn't the fanciest website you have or will ever have seen. But
it's a far cry from [Fefes Blog](https://blog.fefe.de) and still loads
fast and renders reasonably on all devices I could get my hands on.
This is not an accident and I'd like to explain the how and why of
it.

Static Content (Speed)
----------------------

First of all, all content is static. This is why
[GitHub Pages](https://help.github.com/articles/what-is-github-pages/)
and [jekyll](https://jekyllrb.com/) were a perfect fit for me. This
also means no commenting system. It is possible to integrate them,
but I want my content to be served from a single source. If you want
to discuss my articles, you can do so on Twitter, G+ or write your
point of view in your own blog.

### Why?

Static content is caching friendly. GitHub sets the maximum caching
time to 10 minutes, I think an hour or twelve would be more appropriate,
but 10 minutes suffice to have all icons, logos and styles only load
once while browsing the site picking the articles to read. Static
pages are fast, can be served compressed without additional CPU load
on the server (which GH doesn't) and have low traffic costs, because
there is no ongoing communication between the server and the client
(browser).

Fixed Size Icons (Speed)
------------------------

Icons and logos in the main layout (i.e. heading, footer) have a fixed
size.

### Why?

This allows the browser to start rendering the page when the CSS is
loaded, without having to wait for images to load.

CSS3 Media Queries (Rendering)
------------------------------

CSS3 media queries allow one to make rendering decisions, not just
based on the kind of device, but on device properties. This page has
4 different CSS rendering modes.

print
: Only renders content (no header, footer, side bars), does not use
  background colours.

screen
: Background colours, fixed header, footer and side bars are enabled.

screen less than 720pt wide
: Gets rid of side bars to preserve space for content.

screen less than 420pt wide
: Smaller logo in the header and the header is no longer fixed so
  it scrolls out of the way on small screens.

The side bars show social media sharing links, tags and a table of
contents (TOC). The tags are inlined into the content when the side
bars are deactivated, the rest is dropped.

### Why?

This covers a range of viewing devices from very large to very small.
The less than 420pt wide mode ensures that the page renders reasonably,
even when a mobile phone is used in portrait mode (which is the natural
way of using it) as opposed to landscape mode (which is the way a
lot of pages require it to be held to display all relevant content).

Browsers like Firefox or Chromium offer a *Responsive Design View*,
which allow testing these layouts on the development machine. This
page renders reasonably well down to 340px viewport width.

The space used up by the TOC is more valuable than the TOC itself
on small handheld devices. So getting rid of is a sensible option.
Mobile browsers usually have builtin social media sharing functionality,
so dropping it from the page layout is not a loss.
But the tags need to be inlined to preserve their usefulness.

Limit Fixed Size Content (Rendering)
------------------------------------

Fixed size content like images are limited in size with:

~~~ css
#content img {
	max-width:     100%;
	max-height:    calc(100vh - some padding);
}
~~~
Illustrations should fit on the screen.

E.g. look at
[this article]({% post_url 2016-04-07-powerdxx-better-cpu-clock-control-for-freebsd %})
and how the illustrations behave when playing with the *Responsive
Design View*.

For code and verbatim examples, set in a monospace font, I activated
line breaking *inside words* to imitate the behaviour of terminals
and text editors like [vim](http://www.vim.org/):

~~~ css
#content pre {
	white-space:   pre-wrap;
	word-break:    break-all;
}
~~~
Terminal style line wrapping.

### Why?

An illustration should always be viewable as a whole. If your illustrations
have sections that make sense on their own, break them up. Only include
the minimum amount of information necessary in your illustrations
(I am not good at this). If on some device it gets too small to make
sense of it the user can still zoom in and scroll around.

Activating line wrapping and word breaking makes sure that no content
gets lost on devices that do not support scrolling (e.g. printing).
Also the behaviour is target audience appropriate, as it is familiar
behaviour to most developers. Breaking in the middle of a word is a
hint to the viewer that this line break is not part of the code layout.

[According to Scott Meyers](https://library.oreilly.com/book/0636920033707/effective-modern-c/8.xhtml)
you should limit your code lines to 64 characters:

> My decision to limit the line length in code displays to 64 characters
  (the maximum likely to display properly in print as well as across
  a variety of digital devices, device orientations, and font configurations)
  was based on data provided by Michael Maher.

Use Scalable Vector Graphics (Rendering)
----------------------------------------

For logos, icons and possibly illustrations, use scalable vector graphics
(SVG).

### Why?

Traditionally icons and logos would be designed as vector graphics,
converted into pixel graphics for different viewing sizes and hand
optimised to improve contrast and emphasise details that otherwise
would disappear at the given size.

The problem addressed by this technique, is aliasing effects when
rendering a vector graphic at a small size at a low resolution. Luckily
modern devices are either large (PC or notebook screens) or have a
high resolution (mobiles, tablets or notebook screens). What's still
missing is high resolution PC screens, but 8k is on the horizon and
should take care of that. In any way, the problem of rendering small
graphics at low resolutions has all but disappeared.

On the other hand raster images have severe disadvantages at high
resolutions or when zooming in on content. This is relevant to users
in front of small screen devices and the visually impaired.

As an added bonus, SVG is an XML plain text format, so it works well
with git and GitHub.

Stay Away From JavaScript (Speed)
---------------------------------

Using JavaScript can be surprisingly appealing. The ability to query
device properties, parse and manipulate the XML tree and react to
user events often seems convenient and attractive. Don't use it anyway.

### Why?

JavaScript it is a speed drag, CPU hog and notoriously unpopular
within my peer group for wasting energy on mobile devices. Most legitimate
uses that do not require communication with a server have now been
covered by CSS.

Conclusions
-----------

I started with the large screen layout and added the other modes later
on. They did not come as an afterthought, instead I made sure from
the start not to build assumptions into the page layout that would
break it on small screen devices.

Think carefully what to do. E.g. many websites offer CSS pull down
menu navigation on small devices, which is neat (works without scripting).
However seeing the limited number of navigation options at the top
of the page, I deemed it unnecessary.

Avoid fixed elements (elements floating in place over the page content)
on small screens.

Test your changes offline, use the *Responsive Design View* first
and when that works out, use all the viewing devices at your disposal.

Everything you do is a compromise, so bug others to review your site.
They will find things to complain about and make you reconsider the
compromises you have made.

Commit frequently, wait 12 hours before you push changes online unless
it is a bug fix.

If you need to learn more about web design, start with
[w3school's CSS References](http://www.w3schools.com/cssref/).

If you use jekyll, read [their documentation](https://jekyllrb.com/docs/home/)
and the documentation of the
[Liquid Templating Engine](https://shopify.github.io/liquid/).

The only thing I would do differently if I could turn back time would
be to start with the small screen layout and work my way up from
there.
