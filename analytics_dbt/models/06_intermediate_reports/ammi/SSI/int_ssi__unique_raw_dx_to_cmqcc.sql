{{ config(materialized='table') }}

-- the mapping should be unique on raw_dx except O11 and I12 which mapped to 2 category

with unique_dx as (
    select
        dx,
        raw_dx,
        count(*) as dx_count
    from {{ ref('int_ssi__all_dx_features') }}
    group by dx, raw_dx
),

exact_match as (
    select
        unique_dx.raw_dx,
        unique_dx.dx,
        unique_dx.dx_count,
        cmqcc_map.cmqcc_category
    from unique_dx
    left join {{ ref('int_icd_10_to_cmqcc_long') }} cmqcc_map
      on replace(unique_dx.raw_dx, '_', '') like concat(cmqcc_map.dx, '%')
)

select
    *
from exact_match
where cmqcc_category is not null