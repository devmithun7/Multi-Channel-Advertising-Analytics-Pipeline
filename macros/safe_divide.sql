{#
  Division that returns NULL instead of erroring when the denominator is 0
  or NULL.
#}
{% macro safe_divide(numerator, denominator) -%}
    case
        when {{ denominator }} is null or {{ denominator }} = 0 then null
        else {{ numerator }} * 1.0 / {{ denominator }}
    end
{%- endmacro %}
