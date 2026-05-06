{{ config(materialized='table') }}

with cohort as (
    select
        *
    from {{ ref('int_ssi__cohort') }}
),

glucose_raw as (
    select
        patid,
        {{ add_time_to_date_macro('specimen_date', 'specimen_time') }} as specimen_date,
        result_num as glucose
    from {{ ref('lab_result_cm') }}
    where lab_loinc = '2345-7' and result_unit = 'mg/dL' and result_modifier = 'EQ'
),

glucose as (
    select
        cohort.birthid,
        max(glucose) as max_glucose,
        avg(glucose) as mean_glucose,
        case when count(glucose) = 0 then null
             else sum(case when glucose >= 180 then 1 else 0 end)
        end as count_high_glucose_1,
        case when count(glucose) = 0 then null
             else sum(case when glucose >= 130 then 1 else 0 end)
        end as count_high_glucose_2
    from cohort
    left join glucose_raw on cohort.mother_patid = glucose_raw.patid
     and specimen_date between dateadd(day, -3, baby_birth_date) and baby_birth_date
    group by cohort.birthid
),

a1c_raw as (
    select
        patid,
        {{ add_time_to_date_macro('specimen_date', 'specimen_time') }} as specimen_date,
        result_num as a1c
    from {{ ref('lab_result_cm') }}
    where (lab_loinc = '17856-6' or lab_loinc = '4548-4')
      and raw_unit = '%' and result_modifier = 'EQ'
),

a1c as (
    select
        cohort.birthid,
        max(a1c) as max_a1c,
        avg(a1c) as mean_a1c
    from cohort
    left join a1c_raw on cohort.mother_patid = a1c_raw.patid
     and specimen_date between dateadd(day, -90, baby_birth_date) and baby_birth_date
    group by cohort.birthid
)

select
    birthid,
    'max_glucose' as feature_name,
    max_glucose as value
from glucose
where max_glucose is not null

union all

select
    birthid,
    'mean_glucose' as feature_name,
    mean_glucose as value
from glucose
where mean_glucose is not null

union all

select
    birthid,
    'count_high_glucose_1' as feature_name,
    count_high_glucose_1 as value
from glucose
where count_high_glucose_1 is not null

union all

select
    birthid,
    'count_high_glucose_2' as feature_name,
    count_high_glucose_2 as value
from glucose
where count_high_glucose_2 is not null

union all

select
    birthid,
    'max_a1c' as feature_name,
    max_a1c as value
from a1c
where max_a1c is not null

union all

select
    birthid,
    'mean_a1c' as feature_name,
    mean_a1c as value
from a1c
where mean_a1c is not null
