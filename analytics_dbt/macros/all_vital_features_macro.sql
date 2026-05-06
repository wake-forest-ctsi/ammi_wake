{% macro all_vital_features_macro(cohort_table, date1, date2) %}

with cohort as (
    select
        *
    from {{ cohort_table }}
),

vital as (
    select
        patid,
        {{ add_time_to_date_macro("measure_date", "measure_time") }} as measure_date,
        systolic,
        diastolic,
        wt,
        original_bmi
    from {{ ref('vital') }}
    where systolic is not null or diastolic is not null or wt is not null or original_bmi is not null
),

height as (
    select 
        birthid,
        mother_height
    from {{ ref('int_mother_height') }}
),

renamed as (
    select
        cohort.birthid,
        cohort.baby_birth_date,
        cohort.delivery_admit_date,
        vital.measure_date,
        vital.systolic,
        vital.diastolic,
        vital.wt,
        vital.systolic/3.0+2.0*vital.diastolic/3.0 as 'computed_map',
        vital.systolic - vital.diastolic as 'pulse_pressure',
        vital.original_bmi,
        vital.wt*703/(mother_height*mother_height) as 'computed_bmi',
        {{ date1 }} as period_start,
        {{ date2 }} as period_end
    from cohort
    inner join vital on cohort.mother_patid = vital.patid
     and vital.measure_date between {{ date1 }} and {{ date2 }}
    left join height on cohort.birthid = height.birthid   -- height can be missing
)

select * from renamed

{% endmacro %}