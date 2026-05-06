{{ config(materialized='table') }}

with grouped_cte as (
    select
        birthid,
        avg(original_bmi) as original_bmi,
        avg(computed_bmi) as computed_bmi
    from {{ ref('int_depression__all_vital_features') }}
    group by birthid
)

select
    birthid,
    'bmi' as feature_name,
    coalesce(original_bmi, computed_bmi) as value
from grouped_cte