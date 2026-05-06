{% macro group_medadmin_ingredient_features_macro(raw_table, unit_count_table, prefix, before_delivery) %}

with medadmin_ingredient as (
    select
        a.birthid,
        a.baby_birth_date,
        a.ingredient_cui_combined,
        a.medadmin_route,
        cast(a.medadmin_dose_admin as float) medadmin_dose_admin,
        a.medadmin_dose_admin_unit,
        a.medadmin_start_date,
        coalesce(b.unit_is_valid, 0) as unit_is_valid,
        case
          when a.medadmin_dose_admin is null then 0
          when a.medadmin_dose_admin = 0 then 0
          else 1 end as dose_is_valid
    from {{ raw_table }} a
    left join {{ unit_count_table }} b 
      on a.ingredient_cui_combined = b.ingredient_cui_combined
     and a.medadmin_route = b.medadmin_route
     and a.medadmin_dose_admin_unit = b.medadmin_dose_admin_unit
),

grouped_cte as (
    select
        birthid,
        ingredient_cui_combined + '_' + medadmin_route as medadmin_ingredient_key,
        count(*) as total_count,
        {% if before_delivery %}
          max(datediff(minute, medadmin_start_date, baby_birth_date)) as medadmin_ingredient_earliest_minute,
          min(datediff(minute, medadmin_start_date, baby_birth_date)) as medadmin_ingredient_latest_minute,
          max(datediff(minute, medadmin_start_date, baby_birth_date))
          - min(datediff(minute, medadmin_start_date, baby_birth_date)) as medadmin_ingredient_total_duration,
        {% else %}
          min(datediff(minute, baby_birth_date, medadmin_start_date)) as medadmin_ingredient_earliest_minute,
          max(datediff(minute, baby_birth_date, medadmin_start_date)) as medadmin_ingredient_latest_minute,
          max(datediff(minute, baby_birth_date, medadmin_start_date))
          - min(datediff(minute, baby_birth_date, medadmin_start_date)) as medadmin_ingredient_total_duration,
        {% endif %}
        1 as has_medadmin_ingredient,
        avg(case when unit_is_valid = 0 or dose_is_valid = 0 then null else medadmin_dose_admin end) as medadmin_ingredient_avg_dose,
        avg(case when unit_is_valid = 0 or dose_is_valid = 0 then 1.0 else 0.0 end) as medadmin_ingredient_dose_missing_fraction
    from medadmin_ingredient
    group by birthid, ingredient_cui_combined, medadmin_route
)

-- unpivot this table

select
    birthid,
    medadmin_ingredient_key + '{{ prefix }}' + '_medadmin_ingredient_total_count' as feature_name,
    total_count as value
from grouped_cte
where total_count is not null

union all

select
    birthid,
    medadmin_ingredient_key + '{{ prefix }}' + '_medadmin_ingredient_earliest_minute' as feature_name,
    medadmin_ingredient_earliest_minute as value
from grouped_cte
where medadmin_ingredient_earliest_minute is not null

union all

select
    birthid,
    medadmin_ingredient_key + '{{ prefix }}' + '_medadmin_ingredient_latest_minute' as feature_name,
    medadmin_ingredient_latest_minute as value
from grouped_cte
where medadmin_ingredient_latest_minute is not null

union all

select
    birthid,
    medadmin_ingredient_key + '{{ prefix }}' + '_medadmin_ingredient_total_duration' as feature_name,
    medadmin_ingredient_total_duration as value
from grouped_cte
where medadmin_ingredient_total_duration is not null

union all

select
    birthid,
    medadmin_ingredient_key + '{{ prefix }}' + '_has_medadmin_ingredient' as feature_name,
    has_medadmin_ingredient as value
from grouped_cte
where has_medadmin_ingredient is not null

union all

select
    birthid,
    medadmin_ingredient_key + '{{ prefix }}' + '_medadmin_ingredient_avg_dose' as feature_name,
    medadmin_ingredient_avg_dose as value
from grouped_cte
where medadmin_ingredient_avg_dose is not null

union all

select
    birthid,
    medadmin_ingredient_key + '{{ prefix }}' + '_medadmin_ingredient_dose_missing_fraction' as feature_name,
    medadmin_ingredient_dose_missing_fraction as value
from grouped_cte
where medadmin_ingredient_dose_missing_fraction is not null

{% endmacro %}