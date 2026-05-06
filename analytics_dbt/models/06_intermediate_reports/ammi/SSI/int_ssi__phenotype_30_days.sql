{{ config(materialized='table') }}

select
    birthid,
    'target_variable' as 'feature_name',
    case when has_specific_dx = 1 then 1
         when has_less_specific_dx = 1 
          and (has_med_admin = 1 or has_prescribing = 1) then 1
         else 0 end as 'value'
from {{ ref('int_ssi__phenotype_decision_table_30_days') }}