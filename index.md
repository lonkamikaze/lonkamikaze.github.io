---
title: News
---
<ul class="details latest">
	<h4>Latest journal entries …</h4>
{% assign i = 0 %}
{% for post in site.posts %}
{%	if post.journal and i < 5 %}
{%		assign i = i | plus: 1 %}
	<li>
		<a href="{{ post.id }}">
		<div class="date">{{ post.date | date: site.style.date }}</div>
		{{ post.title }}</a>
{%		for tag in post.tags %}{% include tag.html tag=tag %}{% endfor %}
	</li>
{%	endif %}
{% endfor %}
	<li><a href="/journal">More …</a></li>
</ul>
{% for post in site.posts %}
{%	if post.news %}
<h4>
	<div class="date">{{ post.date | date: site.style.date }}</div>
	<a href="{{ post.id }}">{{ post.title }}</a>
{% for tag in post.tags %}	{% include tag.html tag=tag %}
{% endfor %}</h4>
{{ post.excerpt }}
<a href="{{ post.id }}" class="read-more">Read More …</a>
{% endif %}
{% endfor %}
