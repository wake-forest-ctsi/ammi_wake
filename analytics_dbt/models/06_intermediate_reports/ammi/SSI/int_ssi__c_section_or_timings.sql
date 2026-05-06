{{ config(materialized='table') }}

with cohort as (
    select
        birthid,
        baby_birth_date
    from {{ ref('int_ssi__cohort') }}
),

unpivoted as (
    {{
        dbt_utils.unpivot(
            relation=ref('int_c_section_or_timings'),
            cast_to='datetime',
            exclude=['birthid', 'proc_name'],
            field_name='operation_type',
            value_name='operation_time'
        )
    }}
),

-- patients can have both c-section and c-section with tubal ligation can have duplicated record, keep the max
unpivoted_cleaned as (
    select
        birthid,
        operation_type,
        max(operation_time) as operation_time
    from unpivoted
    group by birthid, operation_type
),

relative_minutes as (
    select
        cohort.birthid,
        operation_type,
        operation_time,
        datediff(minute, cohort.baby_birth_date, operation_time) as minute_from_delivery
    from cohort
    left join unpivoted_cleaned on cohort.birthid = unpivoted_cleaned.birthid
),

renamed as (
    select
        birthid,
        'or_timings_' + lower(operation_type) as feature_name,
        minute_from_delivery as value
    from relative_minutes
    where operation_type is not null and minute_from_delivery is not null
)

select * from renamed