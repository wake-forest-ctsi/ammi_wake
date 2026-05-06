{{ config(materialized='table') }}

select
    dx,
    lower(replace(replace(replace(replace(category, '/', '_'), ' ', '_'), ',', '_'), '__', '_')) as cmqcc_category
from {{ ref('icd_10_to_cmqcc') }}