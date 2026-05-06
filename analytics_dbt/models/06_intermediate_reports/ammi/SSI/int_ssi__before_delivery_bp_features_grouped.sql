{{ config(materialized='table') }}

{{
    group_bp_features_macro(
        ref('int_ssi__before_delivery_vital_features'),
        '_before_delivery'
    )
}}