import pandas as pd
from collections import defaultdict

def feature_filter(df_pivoted, skip_medadmin_ingredient=True):
    if not skip_medadmin_ingredient:
        # ===== for has_medadmin_ingredient before delivery =======
        # keep the has_med, and anesthesia_medication_earliest_minute

        neuraxial_anesthesia_features = [x
            for x in df_pivoted.columns \
            if x.endswith('_before_delivery_medadmin_ingredient_earliest_minute')
            and (
                x.startswith('1815_')  # bupivacaine
            or x.startswith('1815+3992_') # bupivacaine + epinephrine
            or x.startswith('1012688_') # Bupivacaine + Fentanyl
            or x.startswith('1012668_') # Bupivacaine + Fentanyl
            or x.startswith('4337_') # Fentanyl
            or x.startswith('7052_') # morphine
            or x.startswith('3992_') # epinephrine alone
            )
        ]
        general_anesthesia_features = [ x
            for x in df_pivoted.columns \
            if x.endswith('_before_delivery_medadmin_ingredient_earliest_minute')
            and (
                x.startswith('8782_')  # propofol
            or x.startswith('6130_') # Ketamine (no use)
            or x.startswith('6960_') # Midazolam 
            or x.startswith('3423_') # Hydromorphone no use
            or x.startswith('73032_') # Remifentanil no use
            )
        ]
        along_anesthesia_features = [ x
            for x in df_pivoted.columns \
            if x.endswith('_before_delivery_medadmin_ingredient_earliest_minute')
            and (
                x.startswith('26225_')  # ondansetron
            or x.startswith('1242902_') # Phenylephrine 
            or x.startswith('1242903_') # Phenylephrine 
            or x.startswith('1242907_') # Phenylephrine 
            or x.startswith('1242909_') # Phenylephrine 
            or x.startswith('8163_') # Phenylephrine
            )
        ]
        incision_related_features = [ x
            for x in df_pivoted.columns \
            if x.endswith('_before_delivery_medadmin_ingredient_earliest_minute')
            and (
                x.startswith('2180_')  # Cefazolin 
            or x.startswith('105202_') # Cefazolin 
            or x.startswith('213891_') # Cefazolin 
            or x.startswith('20859_') # Chloroprocaine  
            or x.startswith('6387_') # Lidocaine  
            or x.startswith('3992+6387_') # Lidocaine + epinephrine 
            )
        ]
        features_to_keep = neuraxial_anesthesia_features + general_anesthesia_features + along_anesthesia_features + incision_related_features

        cols_todo = [x for x in df_pivoted.columns if '_before_delivery' in x and 'medadmin_ingredient' in x]
        cols_to_drop = []
        for col in cols_todo:
            if not col.endswith('has_medadmin_ingredient') and col not in features_to_keep:
                cols_to_drop.append(col)
        df_pivoted = df_pivoted.drop(columns=cols_to_drop).copy()
        print(f"dropping: {cols_to_drop}")

        # ===== for has_medadmin_ingredient after delivery =======
        # keep the has_med, and earliest_minute
        cols_todo = [x for x in df_pivoted.columns if '_after_delivery' in x and 'medadmin_ingredient' in x]
        cols_to_drop = []
        for col in cols_todo:
            if not col.endswith('has_medadmin_ingredient') and not col.endswith('earliest_minute'):
                cols_to_drop.append(col)
        df_pivoted = df_pivoted.drop(columns=cols_to_drop).copy()
        print(f"dropping: {cols_to_drop}")

    # ==== for dx =====
    # keep only has_dx and has_cmqcc, group the Z_counts and drop the original has_dx
    cols_to_drop = [x for x in df_pivoted.columns
                    if x.endswith('_dx_count')
                    or x.endswith('_cmqcc_category_count')]
    cols_todo = [x for x in df_pivoted.columns if x.endswith('_dx_count')]
    cols_to_count = defaultdict(list)
    for x in cols_todo:
        code = x[:x.index('_dx_count')]
        if code[:3] in ['Z23', 'Z31', 'Z32', 'Z33', 'Z34', 'Z36', 'Z3A']:
            cols_to_count[code[:3]].append(x)
            cols_to_drop.append(f"{code}_has_dx")
    cols_to_add = []
    for k, v in cols_to_count.items():
        cols_to_add.append(f'{k}_all_dx_count')
        df_pivoted[f'{k}_all_dx_count'] = df_pivoted[v].sum(axis=1)
    print(f"adding Z counts columns: {cols_to_add}")
    df_pivoted = df_pivoted.drop(columns=cols_to_drop).copy()
    print(f"dropping: {cols_to_drop}")

    # ==== for bp =====
    # keep on all and systolic and diastolic seem enough
    cols_todo = [x for x in df_pivoted.columns if x.startswith('bp') or 'systolic_' in x or 'diastolic_' in x or 'computed_map_' in x]
    cols_to_keep = ['bp_all_count_value',
                    'diastolic_all_max_value',
                    'diastolic_all_mean_value',
                    'diastolic_all_min_value',
                    'diastolic_all_std_value',
                    'systolic_all_max_value',
                    'systolic_all_mean_value',
                    'systolic_all_min_value',
                    'systolic_all_std_value']
    cols_to_drop = []
    for x in cols_todo:
        if x not in cols_to_keep:
            cols_to_drop.append(x)
    df_pivoted = df_pivoted.drop(columns=cols_to_drop).copy()
    print(f"dropping: {cols_to_drop}")

    # ==== for wt
    # use obmi level and rate, plus wt level
    cols_to_drop = [x for x in df_pivoted.columns if x.startswith('wt_') and \
                    ('_first_value' not in x and '_last_value' not in x)]
    cols_to_drop += [x for x in df_pivoted.columns if x.startswith('computed_bmi_')]
    cols_to_drop += [x for x in df_pivoted.columns if x.startswith('original_bmi_') and \
                    ('_first_value' not in x and '_last_value' not in x and '_per_month' not in x)]
    df_pivoted = df_pivoted.drop(columns=cols_to_drop).copy()
    print(f"dropping: {cols_to_drop}")
    return df_pivoted