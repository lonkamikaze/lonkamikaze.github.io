---
title: News
---
{% for post in site.posts %}
{% if post.news %}
<h4>
	<div class="date">{{ post.date | date: site.style.date }}</div>
	<a href="{{ post.id }}">{{ post.title }}</a>
{% for tag in post.tags %}	{% include tag.html tag=tag %}
{% endfor %}</h4>
{{ post.excerpt }}
<a href="{{ post.id }}" class="read-more">Read More …</a>
{% endif %}
{% endfor %}
