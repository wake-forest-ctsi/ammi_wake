{{ config(materialized='table') }}

{{
    group_bp_features_macro(
        ref('int_ssi__after_delivery_vital_features'),
        '_after_delivery'
    )
}}