with cohort as (
    select
        birthid,
        delivery_admit_date,
        baby_birth_date,
        delivery_discharge_date,
        mother_encounterid,
        {{ dbt.datediff('delivery_admit_date', 'baby_birth_date', 'minute') }} as minute_from_admission_to_delivery,
        {{ dbt.datediff('baby_birth_date', 'delivery_discharge_date', 'minute') }} as minute_from_delivery_to_discharge
    from {{ ref('int_cohort') }}
),

membrane_ruptured as (
    select
        patid,
        encounterid,
        cast(obsclin_result_num as float) * 60.0 as minute_membrane_ruptured_to_delivery
    from {{ ref('obs_clin') }}
    where obsclin_code = '106790-9'
),

second_stage_labor as (
    select
        patid,
        encounterid,
        cast(obsclin_result_num as float) * 60.0 as minute_second_stage_labor
    from {{ ref('obs_clin') }}
    where obsclin_code = '110419-4'
),

renamed as (
    select
        birthid,
        max(minute_from_admission_to_delivery) as minute_from_admission_to_delivery,
        max(minute_from_delivery_to_discharge) as minute_from_delivery_to_discharge,
        max(minute_membrane_ruptured_to_delivery) as minute_membrane_ruptured_to_delivery,
        max(minute_second_stage_labor) as minute_second_stage_labor
    from cohort
    left join membrane_ruptured on cohort.mother_encounterid = membrane_ruptured.encounterid
    left join second_stage_labor on cohort.mother_encounterid = second_stage_labor.encounterid
    group by birthid
)

select * from renamed