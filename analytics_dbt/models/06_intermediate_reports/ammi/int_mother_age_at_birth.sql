with cohort as (
    select 
        *
    from {{ ref('int_cohort') }}
),

mother_demographic as (
    select
        patid,
        birth_date
    from {{ ref('demographic') }}
),

renamed as (
    select
        a.birthid,
        {{ dbt.datediff('b.birth_date', 'a.baby_birth_date', 'year') }} as mother_age
    from cohort a
    inner join mother_demographic b on a.mother_patid = b.patid
)

select * from renamed