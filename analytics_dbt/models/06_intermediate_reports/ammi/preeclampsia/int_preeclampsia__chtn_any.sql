{{ config(materialized='table') }}

select
    birthid,
    'chtn_any' as 'feature_name',
    chronic_hyptertension as 'value'
from {{ ref('int_preeclampsia__chronic_hypertension') }}