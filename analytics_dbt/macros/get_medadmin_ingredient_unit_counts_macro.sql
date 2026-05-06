{% macro get_medadmin_ingredient_unit_counts_macro(raw_table) %}


with filtered_unit as (
    select
        ingredient_cui_combined,
        medadmin_route,
        medadmin_dose_admin_unit
    from {{ raw_table }}
    where medadmin_dose_admin_unit is not null 
      and medadmin_dose_admin_unit != 'NI'
      and medadmin_dose_admin_unit != 'OT'
      and lower(medadmin_dose_admin_unit) not like '%/h'
      and lower(medadmin_dose_admin_unit) not like '%/hr'
),

unit_counts as (
    select
        ingredient_cui_combined,
        medadmin_route,
        medadmin_dose_admin_unit,
        count(*) as unit_count,
        row_number() over (partition by ingredient_cui_combined, medadmin_route order by count(*) desc) as count_rank
    from filtered_unit
    group by ingredient_cui_combined, medadmin_route, medadmin_dose_admin_unit
),

valid_units as (
    select
        ingredient_cui_combined,
        medadmin_route,
        medadmin_dose_admin_unit,
        unit_count,
        case when count_rank = 1 then 1 else 0 end as unit_is_valid
    from unit_counts
)

select * from valid_units

{% endmacro %}