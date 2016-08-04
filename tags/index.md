---
title: Tags
---
<div id="tagspage">
{% for tag in site.tags %}
	<h2 id="tag-{{ tag[0] | escape }}">{{ tag[0] }}</h2>
	<ul>
{%	for post in tag[1] %}
		<li>
			<a href="{{ post.id }}">
				<div class="date">{{ post.date | date: site.style.date }}</div>
				{{ post.title }}
			</a>
{%		for tag in post.tags %}{% include tag.html tag=tag %}{%	endfor %}
		</li>
{%	endfor %}
	</ul>
{% endfor %}
</div>
