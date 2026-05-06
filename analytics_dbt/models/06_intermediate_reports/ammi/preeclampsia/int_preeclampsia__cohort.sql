{{ config(materialized='table') }}

with cohort as (
    select
        *
    from {{ ref('int_cohort') }}
),

bp as (
    select
        patid,
        {{ add_time_to_date_macro("measure_date", "measure_time") }} as measure_date
    from {{ ref('vital') }}
    where systolic is not null and diastolic is not null
),

birthid_selected as (
    select
        distinct cohort.birthid
    from cohort
    inner join bp on bp.patid = cohort.mother_patid
      and measure_date between cohort.estimated_preg_start_date and {{ dbt.dateadd('week', 20, 'cohort.estimated_preg_start_date') }}
),

renamed as (
    select
        cohort.*
    from cohort
    inner join birthid_selected on cohort.birthid = birthid_selected.birthid
)

select * from renamed