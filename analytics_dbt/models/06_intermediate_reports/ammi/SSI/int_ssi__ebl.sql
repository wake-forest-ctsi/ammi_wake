{{ config(materialized='table') }}

with cohort as (
    select
        *
    from {{ ref('int_ssi__cohort') }}
),

ebl as (
    select
        patid,
        {{ add_time_to_date_macro('obsclin_start_date', 'obsclin_start_time') }} obsclin_start_date,
        obsclin_result_num as ebl
    from {{ ref('obs_clin') }}
),

renamed as (
    select
        cohort.birthid,
        'estimated_blood_loss' as feature_name,
        max(ebl) as value
    from cohort
    left join ebl on cohort.mother_patid = ebl.patid
     and ebl.obsclin_start_date between {{ dbt.dateadd('day', -1, 'cohort.delivery_admit_date')}} and cohort.delivery_discharge_date
    group by cohort.birthid 
)

select * from renamed where value is not null