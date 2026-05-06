-- depends_on: {{ ref('int_ssi__after_delivery_medadmin_ingredient_features') }}
-- depends_on: {{ ref('int_ssi__after_delivery_medadmin_ingredient_unit_counts') }}

{{ config(materialized='table') }}

{{
    group_medadmin_ingredient_features_macro(
        'int_ssi__after_delivery_medadmin_ingredient_features',
        'int_ssi__after_delivery_medadmin_ingredient_unit_counts',
        '_after_delivery',
        False
    )
}}

