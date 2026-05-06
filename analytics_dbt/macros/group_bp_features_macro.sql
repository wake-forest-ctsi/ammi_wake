{% macro group_bp_features_macro(raw_table, prefix, freq_unit='minute') %}

{% set features = ['systolic', 'diastolic', 'computed_map'] %}

with other_stat_cte as (
    select
        birthid,
        {% for f in features %}
            avg({{ f }}) as {{ f }}_mean_value,
            min({{ f }}) as {{ f }}_min_value,
            max({{ f }}) as {{ f }}_max_value,
            stdev({{ f }}) as {{ f }}_std_value,
            count({{ f }}) as {{ f }}_count_value,
        {% endfor %} 
        min(period_start) as period_start,
        max(period_end) as period_end
    from {{ raw_table }}
    where systolic is not null and diastolic is not null
    group by birthid
)

{% for f in features %}
select
    birthid,
    '{{ f }}' + '{{ prefix }}' + '_mean_value' as feature_name,
    {{ f }}_mean_value as value
from other_stat_cte
where {{ f }}_mean_value is not null

union all

select
    birthid,
    '{{ f }}' + '{{ prefix }}' + '_min_value' as feature_name,
    {{ f }}_min_value as value
from other_stat_cte
where {{ f }}_min_value is not null

union all

select
    birthid,
    '{{ f }}' + '{{ prefix }}' + '_max_value' as feature_name,
    {{ f }}_max_value as value
from other_stat_cte
where {{ f }}_max_value is not null

union all

select
    birthid,
    '{{ f }}' + '{{ prefix }}' + '_std_value' as feature_name,
    {{ f }}_std_value as value
from other_stat_cte
where {{ f }}_std_value is not null

union all
{% endfor %}

select
    birthid,
    'bp' + '{{ prefix }}' + '_count_value' as feature_name,
    systolic_count_value as value
from other_stat_cte
where systolic_count_value is not null

union all

select
    birthid,
    'bp' + '{{ prefix }}' + '_count_per_' + '{{ freq_unit }}' + '_value' as feature_name,
    systolic_count_value / nullif(cast(datediff({{ freq_unit }}, period_start, period_end) as float), 0) as value
from other_stat_cte
where systolic_count_value is not null

{% endmacro %}