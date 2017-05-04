{% assign feature = include.f | split: "#" %}
{% assign link = feature.last | replace: "_", " " %}
[{{ link }}]: http://en.cppreference.com/w/cpp/language/{{ include.f }}
