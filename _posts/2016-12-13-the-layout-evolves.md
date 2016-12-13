---
title: The Layout Evolves
news:  1
tag:
- meta
- web-design
---

[tagspage]: {% post_url 2016-12-07-a-tags-page-for-jekyll %}
A couple of days ago I published an article about
[my jekyll/Liquid tagging system][tagspage] for this site. Writing
about this blog, that I made to write about *other* things, usually
begets some changes.

Links
-----

Here is a nice one:

~~~ css
article a[href*="://"]::after {
	content:             "□➟\02003";
	vertical-align:      super;
	font-size:           75%;
	letter-spacing:      -.5em;
}
~~~
Mark off site links.

This CSS rule matches links which specify a protocol and thus are
assumed to lead off site. It renders a square with an arrow pointing
out of it (borrowing the symbolism from Wikipedia)
[like this](https://www.freebsd.org).

It uses negative letter spacing to overlap the arrow and the square.
The `\02003` is an `em` wide space inserted behind the symbol to
work around a bug in Firefox that cuts off the tip of the arrow. A
regular space wouldn't work here, because it is less wide than `.5em`,
causing even more of the arrow to be cut off.

Contrast/Colours
----------------

Because I didn't like the low contrast of the site, I added borders
to the [heading](#) and the [footer](#footer) and shifted some colours,
most prominently I found a nicer colour for tags.

I picked a brighter tone of red from the colour palette of the
[logo](/img/logo.svg). I hope this looks less threatening. I also
switched the hover effect from a colour shift to a blurred shadow.
This is surprisingly effective at drawing the users' attention:

~~~ css
a:hover {
	text-shadow:         0pt 0pt .1ex;
}
~~~
Add a blurry shadow to the link under the cursor.

Having the shadow size scale along with the font size by using the
unit ex (em would work too), is also nice.

Escapes
-------

I also added some `escape`/`url_encode` filters to the templates
for the site, in places where so far only my personal conventions
ensured proper encoding. As a result I also updated the
[article about tags][tagspage].

Low/High DPI
------------

A bit longer ago I added a CSS rule to use a sans-serif font on low
resolution devices. I didn't find any literature that makes an empirical
argument about where the tipping point for better readability is.
So I made a conservative decision that any device with a resolution
less than or equal to 240 dpi should match the rule.

To my surprise I found that Mobile Firefox on my Android phone (400 dpi)
rendered the page sans-serif. The serif version definitely looks
better at this resolution. The cause it turned out is that Firefox's
default font is sans-serif and the default is what I use when the
low resolution rule does not apply.

I'm all in favour of obeying user defaults when it comes to fonts
(that's why I only use the font-families serif, sans-serif and monospace
in my CSS rules). So instead I changed the default font of Firefox.
The mobile version does not offer that option in the settings, but
you can go to `about:config` and change `font.default.x-western` to
`serif`.
