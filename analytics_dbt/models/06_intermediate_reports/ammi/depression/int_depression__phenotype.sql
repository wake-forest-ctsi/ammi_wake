{{ config(materialized='table') }}

with cohort as (
    select
        *
    from {{ ref('int_depression__cohort') }}
),

dx_code as (
    select
        patid,
        dx_date,
        1 as 'has_dx'
    from {{ ref('diagnosis') }}
    where dx = 'F53.0'
),

other_dx_code as (
    select
        patid,
        dx_date,
        1 as 'has_dx'
    from {{ ref('diagnosis') }}
    where dx like 'F32%' or dx like 'F33%' or dx like 'F34.1%' or dx like 'F53.0'
),

epds as (
    select
        patid,
        {{ add_time_to_date_macro("obsclin_start_date", "obsclin_start_time") }} obsclin_start_date,
        obsclin_result_num,
        1 as 'has_epds'
    from {{ ref('obs_clin') }}
    where obsclin_code = '99046-5' or obsclin_code = '71354-5'
),

phq9 as (
    select
        patid,
        {{ add_time_to_date_macro("obsclin_start_date", "obsclin_start_time") }} obsclin_start_date,
        obsclin_result_num,
        1 as 'has_phq9'
    from {{ ref('obs_clin') }}
    where obsclin_code = '21012959'
),

all_posibilities as (
    select
        cohort.birthid,
        max(coalesce(dx_code.has_dx, 0)) as dx_code,
        max(epds.obsclin_result_num) as max_epds,
        max(phq9.obsclin_result_num) as max_phq9,
        max(coalesce(other_dx_code.has_dx, 0)) as other_dx_code
    from cohort
    left join dx_code on cohort.mother_patid = dx_code.patid
     and dx_code.dx_date between cohort.baby_birth_date and dateadd(year, 1, cohort.baby_birth_date)
    left join epds on cohort.mother_patid = epds.patid
     and epds.obsclin_start_date between cohort.baby_birth_date and dateadd(year, 1, cohort.baby_birth_date)
    left join phq9 on cohort.mother_patid = phq9.patid
     and phq9.obsclin_start_date between cohort.baby_birth_date and dateadd(year, 1, cohort.baby_birth_date)
    left join other_dx_code on cohort.mother_patid = other_dx_code.patid
     and other_dx_code.dx_date between cohort.baby_birth_date and dateadd(year, 1, cohort.baby_birth_date)
    group by cohort.birthid
)

select
    birthid,
    'target_variable' as feature_name,
    case when dx_code = 1 or max_epds >= 10 or max_phq9 >= 10 then 1 else 0 end as value
from all_posibilities

-- union all

-- select
--     birthid,
--     'has_screened' as feature_name,
--     case when has_epds = 1 or has_phq9 = 1 then 1 else 0 end as value
-- from all_posibilities

-- for reproducing the label comparison in the paper

union all

select
    birthid,
    'F53_label' as feature_name,
    dx_code as value
from all_posibilities

union all

select
    birthid,
    'edinburgh_max' as feature_name,
    max_epds as value
from all_posibilities

union all

select
    birthid,
    'phq9_total_max' as feature_name,
    max_phq9 as value
from all_posibilities

union all

select
    birthid,
    'other_dx_code' as feature_name,
    other_dx_code as value
from all_posibilities
