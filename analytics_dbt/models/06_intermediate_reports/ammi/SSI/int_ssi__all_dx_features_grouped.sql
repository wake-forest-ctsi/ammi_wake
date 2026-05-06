{{ config(materialized='table') }}

with dx as (
    select
        birthid,
        dx,
        raw_dx
    from {{ ref('int_ssi__all_dx_features') }}
),

dx_cmqcc_mapped as (
    select
        dx.*,
        cmqcc_category
    from dx
    left join {{ ref('int_ssi__unique_raw_dx_to_cmqcc') }} cmqcc
      on dx.raw_dx = cmqcc.raw_dx
),

grouped_dx_cte as (
    select
        dx.birthid,
        dx.dx,
        1 as has_dx,
        count(*) as dx_count
    from dx
    group by dx.birthid, dx.dx
),

grouped_cmqcc_cte as (
    select
        birthid,
        cmqcc_category,
        1 as has_cmqcc_category,
        count(*) as cmqcc_category_count
    from dx_cmqcc_mapped
    where cmqcc_category is not null
    group by birthid, cmqcc_category
)

-- unpivot these

select
    birthid,
    dx + '_has_dx' as feature_name,
    has_dx as value
from grouped_dx_cte

union all

select
    birthid,
    dx + '_dx_count' as feature_name,
    dx_count as value
from grouped_dx_cte

union all

select
    birthid,
    cmqcc_category + '_has_cmqcc_category' as feature_name,
    has_cmqcc_category as value
from grouped_cmqcc_cte

union all

select
    birthid,
    cmqcc_category + '_cmqcc_category_count' as feature_name,
    cmqcc_category_count as value
from grouped_cmqcc_cte