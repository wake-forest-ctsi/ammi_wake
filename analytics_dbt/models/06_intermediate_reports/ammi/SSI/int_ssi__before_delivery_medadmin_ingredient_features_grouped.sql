-- depends_on: {{ ref('int_ssi__before_delivery_medadmin_ingredient_features') }}
-- depends_on: {{ ref('int_ssi__before_delivery_medadmin_ingredient_unit_counts') }}

{{ config(materialized='table') }}

{{
    group_medadmin_ingredient_features_macro(
        'int_ssi__before_delivery_medadmin_ingredient_features',
        'int_ssi__before_delivery_medadmin_ingredient_unit_counts',
        '_before_delivery',
        True
    )
}}

