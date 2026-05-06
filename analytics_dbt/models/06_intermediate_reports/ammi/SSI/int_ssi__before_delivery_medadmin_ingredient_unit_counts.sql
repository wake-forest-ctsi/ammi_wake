{{ config(materialized='table') }}

{{
    get_medadmin_ingredient_unit_counts_macro(
        'int_ssi__before_delivery_medadmin_ingredient_features'
    )
}}