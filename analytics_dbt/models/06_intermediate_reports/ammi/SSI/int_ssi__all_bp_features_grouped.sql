{{ config(materialized='table') }}

{{
    group_bp_features_macro(
        ref('int_ssi__all_vital_features'),
        '_all',
        'week'
    )
}}