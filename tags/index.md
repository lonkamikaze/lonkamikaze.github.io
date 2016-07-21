---
title: Tags
---
<div id="tagspage">
{% for tag in site.tags %}
	<a name="{{ tag[0] | escape }}"></a>
	<h4>{{ tag[0] }}</h4>
	<ul>
{%	for post in tag[1] %}
		<li>
			<div class="date">{{ post.date | date: site.style.date }}</div>
			<a href="{{ post.id }}">{{ post.title }}</a>
{%		for tag in post.tags %}
			{% include tag.html tag=tag %}
{%		endfor %}
		</li>
{%	endfor %}
	</ul>
{% endfor %}
</div>
