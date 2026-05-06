{{ 
    all_medadmin_ingredient_features_macro(
      ref('int_ssi__cohort'),
      10,
      "cohort.baby_birth_date",
      "cohort.delivery_discharge_date"
    ) 
}}