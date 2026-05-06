{% macro all_medadmin_ingredient_features_macro(cohort_table, min_count, date1, date2) %}

with cohort as (
    select
        *
    from {{cohort_table }} cohort
),

rx as (
    select
        patid,
        medadmin_code,
        {{ add_time_to_date_macro('medadmin_start_date', 'medadmin_start_time') }} as medadmin_start_date,
        medadmin_dose_admin,
        medadmin_dose_admin_unit,
        medadmin_route,
        lower(raw_medadmin_med_name) as medadmin_med_name,
        medadmin_providerid
    from {{ ref('med_admin') }}
),

rx_selected as (
    select
        cohort.birthid,
        cohort.mother_patid,
        cohort.baby_birth_date,
        cohort.estimated_preg_start_date,
        cohort.delivery_admit_date,
        rx.medadmin_code,
        rx.medadmin_dose_admin,
        rx.medadmin_dose_admin_unit,
        rx.medadmin_route,
        rx.medadmin_start_date,
        rx.medadmin_med_name,
        rx.medadmin_providerid
    from cohort
    inner join rx on cohort.mother_patid = rx.patid 
     and rx.medadmin_start_date between {{ date1 }} and {{ date2 }}
),

ingredient_selected as (
    select
        birthid,
        mother_patid,
        baby_birth_date,
        estimated_preg_start_date,
        delivery_admit_date,
        medadmin_code,
        case when ingredient_cui_combined is null then medadmin_code
             else ingredient_cui_combined end as ingredient_cui_combined,
        medadmin_dose_admin,
        medadmin_dose_admin_unit,
        medadmin_route,
        medadmin_start_date,
        medadmin_med_name,
        medadmin_providerid
    from rx_selected
    left join {{ ref('rxnorm_product_identity') }} mapping
      on rx_selected.medadmin_code = mapping.raw_rxcui
),

ingredient_count as (
    select
        ingredient_cui_combined
    from ingredient_selected
    group by ingredient_cui_combined
    having count(distinct birthid) >= {{ min_count }}
),

renamed as (
    select
        ingredient_selected.birthid,
        ingredient_selected.mother_patid,
        ingredient_selected.baby_birth_date,
        ingredient_selected.estimated_preg_start_date,
        ingredient_selected.delivery_admit_date,
        ingredient_selected.medadmin_code,
        ingredient_selected.ingredient_cui_combined,
        ingredient_selected.medadmin_dose_admin,
        ingredient_selected.medadmin_dose_admin_unit,
        case
          when ingredient_selected.medadmin_route is null then 'UNKNOWN'
          when ingredient_selected.medadmin_route in ('OT', 'NI') then 'UNKNOWN'
          else ingredient_selected.medadmin_route end as medadmin_route,
        ingredient_selected.medadmin_start_date,
        ingredient_selected.medadmin_med_name,
        ingredient_selected.medadmin_providerid
    from ingredient_selected
    inner join ingredient_count on ingredient_selected.ingredient_cui_combined = ingredient_count.ingredient_cui_combined
)

select * from renamed

{% endmacro %}