with joined as (
    select
        a.birthid as birthid,
        b.birthid as sibling_birthid,
        a.baby_birth_date as baby_birth_date,
        b.baby_birth_date as sibling_birth_date
    from {{ ref('int_cohort') }} a
    left join {{ ref('int_cohort') }} b 
      on a.mother_patid = b.mother_patid
     and abs(datediff(day, a.baby_birth_date, b.baby_birth_date)) <= 1
),

renamed as (
    select
        birthid,
        count(distinct sibling_birthid) as birth_counts
    from joined
    group by birthid
)

select * from renamed
