{% macro add_time_to_date_macro(date_col, time_col) %}
    {# 
      Returns a single timestamp/datetime if both parts are valid; otherwise NULL.
      - For SQL Server: use TRY_CONVERT to avoid errors;
      - For DuckDB: use try_cast to avoid errors.
    #}
    {% if target.type == 'sqlserver' %}
        case
            when try_convert(datetime, {{ date_col }}) is not null
             and try_convert(datetime, {{ time_col }}) is not null
            then try_convert(datetime, {{ date_col }})
               + try_convert(datetime, {{ time_col }})
            else null
        end
    {% else %}
        -- duckdb (and most ansi-ish engines): use try_cast, sum date + time
        case
            when try_cast({{ date_col }} as date) is not null
             and try_cast({{ time_col }} as time) is not null
            then try_cast({{ date_col }} as date)
               + try_cast({{ time_col }} as time)
            else null
        end
    {% endif %}
{% endmacro %}