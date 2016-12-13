---
title:   A Tags Page for Jekyll
journal: 1
update:  2016-12-13
tags:
- web-design
- jekyll
- liquid
---

[jekyll]: https://jekyllrb.com/
[Liquid]: https://shopify.github.io/liquid/
[GitHub Pages]: https://pages.github.com/
The [jekyll] site generator used for this blog as part of the
[GitHub Pages] hosting service offers a simple tagging mechanism.
What it does not offer is generating tag pages that show all the
content with a specified tag.

For this article you are expected to already use jekyll and have the
basics of writing articles and working with templates down. Technical
details of jekyll/Liquid are only covered to provide emphasis on
relevant details.

Known Solutions
---------------

When searching for the problem
[a blog post from 2011](http://charliepark.org/tags-in-jekyll/)
seems to be the only solution offered. The solution is a jekyll plugin
that generates pages. Because custom plugins cannot be used on GH Pages,
that means committing these generated pages to the repository along
with the content.

This breaks the abstraction provided by jekyll and reinforced by the
GH Pages policy of auto-publishing, that templates and page content
are part of the repository, but the HTML served to the browser isn't.

Jekyll and Liquid
-----------------

[Jekyll] is powered by the [liquid] template engine, which offers
a number of [data types](https://shopify.github.io/liquid/basics/types/):
`numeric`, `boolean`, `string` and `array`.

Every article starts with a block that defines a number of variables
encoding information about the site. E.g. for this page the block
looks like this:

~~~ md
---
title:   A Tags Page for Jekyll
journal: 1
tags:
- web-design
- jekyll
- liquid
---

…
~~~
The header for this article.

The `tags` list defines an array `tags={"web-design","jekyll","liquid"}`.
The `title` definition a `string` and journal a `numeric`.

This information is provided to the Liquid engine by jekyll in an
object. An object is Liquid's term for a dictionary. Jekyll provides
several objects like `site` for information about the whole site and
`page` for information about the current page.

So the `tags` array can be accessed by Liquid as `page.tags`. The
jekyll documentation has [an overview](https://jekyllrb.com/docs/variables/)
of the available objects.

Building a Solution Based on Liquid
-----------------------------------

The approach used for this blog relies on the Liquid engine and CSS3.

The idea is to write a single page for all tags, and then use CSS
to hide the content that is currently not relevant.

### Linking to Tags

Having a page that shows all pages with a certain tag is not enough,
blog articles need to display their tags and reference the page.

I.e. a link to the tag `web-design` looks like this:

~~~ html
<a class="tag" href="/tags#tag:web-design">web-design</a>
~~~
Linking to a specific tag.

The `tag` class serves giving tags a distinct style in the layout
(which is not covered here). The interesting part is the URL in the
`href` attribute. The path compontent `/tags` refers to what will
later become the tag display page, in the case of this blog
`tags/index.html` in the repository. The fraction `#tag:web-design`
contains the tag. To avoid ambiguities the tag is prefixed by `tag:`.

The target page needs to have an HTML element with the attribute
`id="tag:web-design"` for the link to work. Valid ids may contain
any non-whitespace character. To allow spaces in tags, spaces can
be substituted by an underscore. URLs are less liberal about permitted
characters, so tags in the URL should be URL encoded.

E.g. a list of tags can be generated like this:

~~~ liquid
{% raw %}{% for tag in post.tags %}
	<a class="tag" href="/tags#tag:{{ tag | replace: " ", "_" | url_encode }}">{{ tag | escape }}</a>
{% endfor %}{% endraw %}
~~~
Creating a link for each tag.

This can be put into the layout wherever you wish. And of course
you can add sugar to it, like generating an unordered list.

### The Tags Page

For this blog the tags page has been created under `tags/index.html`.
Jekyll provides a list of all tags, across all pages in the `site`
object under `site.tags`.

I used good old trial and error to figure out how `site.tags` is
structured. If it's documented somewhere I don't know where.

Each tag in `site.tags` is an array itself. The array contains a
tuple with `tag[0]` containing the name of the tag and `tag[1]` containing
an array of post objects, with all the info that entails (e.g. title,
date, tags etc.).

This is the basic code to iterate through it:

~~~ liquid
{% raw %}{% for tag in site.tags %}
tag: {{ tag[0] }}
posts:
{%	for post in tag[1] %}
	date:  {{ post.date }}
	url:   {{ post.id }}
	title: {{ post.title }}
	{% for tag in post.tags %}…you already know this one…{% endfor %}
{%	endfor %}
{% endfor %}{% endraw %}
~~~
Iterating to the global list of tags.

This is a good moment to step back and look at the HTML structure
of this site. Specifically where the content goes:

	<html> → <body> → <main> → <article> → contents

An HTML5 style page structure.

This is a pretty standard HTML5 structure and it means everything
we do in `tags/index.html` ends up in an `<article>` tag. As far
as this page is concerned `<article>` is the document root.

HTML5 allows us to split an `<article>` into sections using `<section>`.
This blog uses a section for each tag:

~~~ liquid
{% raw %}{% for tag in site.tags %}
<section id="tag:{{ tag[0] | replace: " ", "_" }}">
	<h1>{{ tag[0] | escape }}</h1>
	<ul>
{%	for post in tag[1] %}
		<li>…this is up to you…</li>
{%	endfor %}
	</ul>
</section>
{% endfor %}{% endraw %}
~~~
Creating a section for each tag.

At this point you have a page that shows you all tags and all the
posts that are tagged with each tag.

You can link to it and the browser will jump to the right tag  (if
possible), but you will still have all the other content clutter up
your page. This can be resolved by combining an HTML5 feature, scoped
styles, with a CSS3 feature, the `:target` selector.

A scoped style is a style definition that may appear outside of the
document `<head>` (which is usually illegal, but accepted by all
browsers). The scoped style can affect everything inside its parent
node, as well as the parent node itself, but nothing beyond that.
So it only affects its context (remember our root node is an `<article>`).

The CSS3 `:target` selector selects the element of the document that
was selected by the `#fraction` of the given URL. Put the following
code at the beginning of the document to hide *all* content and unhide
only the selected section:

~~~ html
<style type="text/css" scoped>
/* Hide everything */
article > * {
	display:             none;
}

/* Unhide the selected tag */
article > :target {
	display:             block;
}
</style>
~~~
Get rid of all content, but make an exception for selected content.

The way I understand the standard it should be possible to substitute
`article` with `:root`. To select the root of the current context,
but browsers do not agree on how to treat `:root` inside a scoped
style. Firefox 50 seems to treat it as a violation of the scope rule
and ignores it, Chromium 54 ignores the scope limitation and applies
it to the document root instead of the article. I deem Firefox's
approach *more correct*. But neither behaviour is what I expected.

TL;DR
-----

The complete code for this blog's tags page can be found
[in the repository]({{ site.code }}/tags/index.html).
