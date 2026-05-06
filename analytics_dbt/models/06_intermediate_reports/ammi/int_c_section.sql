{{ config(materialized='table') }}

with cohort as (
    select
        *
    from {{ ref('int_cohort') }}
),

c_section as (
    select
        encounterid,
        min(raw_px) as delivery_mode,
        min(enc_type) as px_enc_type,
        min(admit_date) as px_admit_date,
        min(px_date) as px_date,
        min(providerid) as providerid
    from {{ ref('procedures') }}
    where raw_px like 'C-Section%'
    group by encounterid
),

renamed as (
    select
        cohort.birthid,
        c_section.delivery_mode,
        c_section.px_enc_type,
        c_section.px_admit_date,
        c_section.px_date,
        c_section.providerid
    from cohort
    inner join c_section on cohort.mother_encounterid = c_section.encounterid
)

select * from renamed