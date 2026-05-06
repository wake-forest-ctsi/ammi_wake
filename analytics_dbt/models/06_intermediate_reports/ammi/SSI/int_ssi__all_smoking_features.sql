{{
    all_smoking_macro(
        ref("int_ssi__cohort"),
        "dateadd(year, -1, cohort.baby_birth_date)", 
        "cohort.delivery_admit_date"
    )
}}