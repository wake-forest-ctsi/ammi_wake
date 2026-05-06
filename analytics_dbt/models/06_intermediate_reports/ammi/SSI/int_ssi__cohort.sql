{{ config(materialized='table') }}

with visit_flags as (
    select
        birthid,
        max(case when days_since_child_birth between -268 and -1 then 1 else 0 end) as has_prenatal_visit,
        max(case when days_since_child_birth between 1 and 90 then 1 else 0 end) as has_postpartum_visit
    from {{ ref('int_visits') }}
    group by birthid
),

filtered_births as (
    select
        birthid
    from visit_flags
    where has_prenatal_visit = 1 and has_postpartum_visit = 1
),

renamed as (
    select
        cohort.*
    from {{ ref('int_cohort') }} cohort
    inner join {{ ref('int_c_section') }} csection on cohort.birthid = csection.birthid
    inner join filtered_births on cohort.birthid = filtered_births.birthid
    where cohort.delivery_discharge_date is not null
    and cohort.baby_birth_date >= cohort.delivery_admit_date  -- remove some record that has wrong date/time
    and cohort.delivery_discharge_date >= cohort.baby_birth_date
)

select * from renamed