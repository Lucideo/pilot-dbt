{% macro cents_to_reais(column) %}
({{ column }} / 100.0)::decimal(10, 2)
{% endmacro %}