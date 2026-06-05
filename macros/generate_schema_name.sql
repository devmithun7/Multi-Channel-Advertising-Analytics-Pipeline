{#
  Use the custom schema name verbatim (raw, staging, intermediate, marts)
  instead of dbt's default "<target_schema>_<custom>" prefixing. This keeps
  the warehouse browsable with clean, layer-named schemas.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
