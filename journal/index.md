---
title: Journal
---
{% for post in site.posts %}
{% unless post.draft or post.news %}
<h4>
	<div class="date">{{ post.date | date: site.style.date }}</div>
	<a href="{{ post.id }}">{{ post.title }}</a>
{% for tag in post.tags %}	<span class="tag">{{ tag }}</span>
{% endfor %}</h4>
<div class="update">{{ post.update  | date: "%F" }}</div>
{{ post.excerpt }}
<a href="{{ post.id }}" class="read-more">Read More …</a>
{% endunless %}
{% endfor %}
