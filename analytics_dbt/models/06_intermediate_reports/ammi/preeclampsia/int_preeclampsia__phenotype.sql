{{ config(materialized='table') }}

select
    birthid,
    'target_variable' as 'feature_name',
    case when (chtn_any = 0 and (pre_sf_or_ecl = 1 or bp_cat_after_20wk = 2 or mag_infuse = 1)) then 1  -- i think sipe can be 1 here ??
            when (chtn_any = 0 and (bp_cat_after_20wk >= 1 and lab_others = 1)) then 1
            when (chtn_any = 1 and (pre_sf_or_ecl = 1 or sipe = 1 or mag_infuse = 1)) then 1
            when (chtn_any = 1 and (bp_cat_after_20wk = 2 and lab_proteinuria = 1)) then 1
            when (chtn_any = 1 and (bp_cat_after_20wk >= 1 and lab_others = 1)) then 1  -- i believe this should be >= 1 here otherwise will mis (bp_cat_after_20wk = 2 and lab_others ==1)
            else 0 end as 'value'
from {{ ref('int_preeclampsia__phenotype_decision_table') }}