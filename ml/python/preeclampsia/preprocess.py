import numpy as np
import pandas as pd

def preprocess(df_pivoted):
    # drop records without required columns
    required_cols = ['delivery_year', 'mother_age_at_birth', 'mother_height', 'target_variable']
    print(f"starting shape: {df_pivoted.shape}")
    df_pivoted = df_pivoted.dropna(subset=required_cols).copy()
    print(f"after removing rows without required columns {df_pivoted.shape}")

    # visit counts fill with 0
    cols_todo = [x for x in df_pivoted.columns if x.startswith('enc_type') or x == 'total_visits_count']
    print(f"{cols_todo} will be filled with 0")
    for col in cols_todo:
        df_pivoted[col] = df_pivoted[col].fillna(0)
    
    # parity fill with 0
    if 'parity' in df_pivoted.columns:
        print(f"parity will be filled with 0 and add a marker")
        df_pivoted['parity_isna'] = np.where(df_pivoted['parity'].isna(), 1, 0)
        df_pivoted['parity'] = df_pivoted['parity'].fillna(0)
        df_pivoted['parity_1_recovered'] = df_pivoted['parity_1_recovered'].fillna(0)
        df_pivoted['parity_2_recovered'] = df_pivoted['parity_2_recovered'].fillna(0)
    
    # insurance fill with 0
    cols_todo = [x for x in df_pivoted.columns if x.startswith('insurance_')]
    print(f"{cols_todo} will be filled with 0")
    for col in cols_todo:
        df_pivoted[col] = df_pivoted[col].fillna(0)

    # blood pressure and other vital columns
    cols_todo = [
        'computed_bmi_count_value',
        'original_bmi_count_value',
        'wt_count_value',
        'computed_map_count_value',
        'diastolic_count_value',
        'pulse_pressure_count_value',
        'systolic_count_value'
    ]
    for col in cols_todo:
        code = col[:col.index('_count_value')]
        cols_todo_2 = [x for x in df_pivoted.columns if x.startswith(code) and x != col]
        print(f"{cols_todo_2} will be filled with mean and set the count to 0")
        df_pivoted[col] = df_pivoted[col].fillna(0)
        for col2 in cols_todo_2:
            df_pivoted[col2] = df_pivoted[col2].fillna(df_pivoted[col2].mean())
    
    # rx and dx set to 0
    cols_todo = [x for x in df_pivoted.columns if x.endswith('_has_rx') or x.endswith('_has_dx')]
    print(f"all _has_rx and _has_dx will be filled with 0")
    for col in cols_todo:
        df_pivoted[col] = df_pivoted[col].fillna(0)
    
    return df_pivoted.copy()