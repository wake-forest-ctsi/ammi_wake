{{ 
    all_medadmin_ingredient_features_macro(
      ref('int_ssi__cohort'),
      10,
      "cohort.delivery_admit_date",
      "cohort.baby_birth_date"
    ) 
}}