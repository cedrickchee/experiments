{% set data = load_data(path=path) -%}
{% for book in data.books %}
- {{ book.title }}

  {{ book.description | safe }}
{% endfor %}