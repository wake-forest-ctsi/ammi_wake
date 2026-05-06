{{ config(materialized='table') }}

with cohort as (
    select
        birthid,
        baby_birth_date
    from {{ ref('int_ssi__cohort') }}
),

proc_name as (
    select
        birthid,
        proc_name,
        case_req_datetime,
        row_number() over (partition by birthid order by case_req_datetime desc, proc_name asc) as k
    from {{ ref('int_c_section_or_timings') }}
),

proc_name_last_decision as (
    select
        birthid,
        proc_name
    from proc_name
    where k = 1
),

renamed as (
    select
        cohort.birthid,
        'c_section_sub_type_' + proc_name as feature_name,
        1 as value
    from cohort
    left join proc_name_last_decision on cohort.birthid = proc_name_last_decision.birthid
    where proc_name is not null
)

select * from renamed