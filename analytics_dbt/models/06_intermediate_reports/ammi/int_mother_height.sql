-- for height, fix it to -1 and +1 year from baby_birth_date; or use avg(height) when patient >= 18 yr
-- one pitfall is the patient delivered < 18 yr and no height measurement within +- 1 yr, there will be some backfill problem 

with cohort as (
    select
        birthid,
        mother_patid,
        baby_birth_date
    from {{ ref('int_cohort') }}
),

mother_demographic as (
    select
        patid,
        birth_date
    from {{ ref('demographic') }}
),

-- height get it from vital table which every site has
vital as (
    select
        vital.patid,
        vital.ht as height,
        vital.measure_date,
        {{ dbt.datediff('demographic.birth_date', 'vital.measure_date', 'day') }} / 365.0 as age_at_measure
    from {{ ref('vital') }} vital
    left join mother_demographic demographic on vital.patid = demographic.patid
    where ht is not null and ht > 0
),

-- height priority 1: within +- 1 yr of delivery
height_priority_1 as (
    select 
        a.birthid,
        avg(b.height) as mother_height
    from cohort a
    inner join vital b on a.mother_patid = b.patid
     and measure_date between {{ dbt.dateadd('year', -1, 'a.baby_birth_date') }} and {{ dbt.dateadd('year', 1, 'a.baby_birth_date') }}
    group by a.birthid
),

-- height_priority 2: get all heights >= 18 yrs
height_priority_2 as (
    select
        a.birthid,
        avg(b.height) as mother_height
    from cohort a
    inner join vital b on a.mother_patid = b.patid
    where age_at_measure >= 18.0
    group by a.birthid
),

renamed as (
    select
        a.birthid,
        case 
            when height_priority_1.mother_height is not null then height_priority_1.mother_height
            when height_priority_2.mother_height is not null then height_priority_2.mother_height
            else null 
        end as mother_height
    from cohort a
    left join height_priority_1 on a.birthid = height_priority_1.birthid
    left join height_priority_2 on a.birthid = height_priority_2.birthid
)

select * from renamed