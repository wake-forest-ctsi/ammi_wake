import numpy as np
import pandas as pd
import logging

logger = logging.getLogger(__name__)

# if you have vital table, it can be read from there (sbp, dpb, bmi, wt)
obsclin_repeated_code = ('8480-6', '8462-4', '39156-5', '3141-9')

def preprocess(df_pivoted, drop_repeat_obsclin=True, min_binary_ones=10, *, defer_imputation=False):
    '''
      preprocess the df pivoted dataframe
      - remove rows without required columns
      - drop duplicated
      - if obsclin and vital tables are both included, drop the repeated obsclin measurement
      - for fillna, see each columns below
      - with defer_imputation=True, fit imputation means inside each training
        fold with ClinicalImputer and skip exposure-subset constant screening
    '''
    import numpy as np

    required_cols = ['delivery_year', 'mother_age_at_birth', 'mother_height', 'target_variable']

    # drop records without required columns
    print(f"starting shape: {df_pivoted.shape}")
    df_pivoted = df_pivoted.dropna(subset=required_cols).copy()
    print(f"after removing rows without required columns {df_pivoted.shape}")

    # drop columns with all NaNs
    cols_to_drop = df_pivoted.columns[df_pivoted.isna().all(axis=0)].tolist()
    print("Dropping columns with all NaNs:", cols_to_drop)
    df_pivoted = df_pivoted.drop(columns=cols_to_drop)
    print(f"after removing columns with all NaNs {df_pivoted.shape}")

    # drop duplicated
    df_pivoted = df_pivoted.drop_duplicates(subset=df_pivoted.drop(columns=['birthid'])).copy()
    print(f"after removing duplicated rows {df_pivoted.shape}")

    if drop_repeat_obsclin:
        cols_todo = [x for x in df_pivoted.columns if x.startswith(obsclin_repeated_code)]
        print(f"removing repeating obsclin code {cols_todo}")
        df_pivoted = df_pivoted.drop(columns=cols_todo).copy()
        print(f"after removing duplicated obsclin rows {df_pivoted.shape}")

    tmp = df_pivoted.nunique(dropna=False)
    cols_todo = tmp.index[tmp <= 1].tolist()
    print(f"{cols_todo} has only 1 unique numbers")
    if len(cols_todo) > 0:
        df_pivoted = df_pivoted.drop(columns=cols_todo).copy()
    print(f"after dropping columns with 1 unique value {df_pivoted.shape}")

    # ====== for _has_rx, has_dx and _has_med, fill the column with 0 ======= 
    # and then fill the other columns associate with this code using 0
    cols_todo = [x for x in df_pivoted.columns 
                 if x.endswith('_has_rx') \
                 or x.endswith('_has_dx') \
                 or x.endswith('_has_cmqcc_category') \
                 or x.endswith('_has_ccsr_category') \
                 or x.endswith('_has_elixhauser_category') \
                 or x.endswith('_has_med') \
                 or x.endswith('_has_medadmin_ingredient')]
    print(f"{cols_todo} will be filled with 0")
    df_pivoted[cols_todo] = df_pivoted[cols_todo].fillna(0)

    isna_cols = {}
    cols_to_drop = []
    deferred_exposure_columns = []
    for col in cols_todo:
        # find the relevant columns
        code = col[:col.index('_has')]
        relevant_cols = [x for x in df_pivoted.columns if x.startswith(code) and x not in cols_todo]

        # now fillna for each relevant columns
        for relevant_col in relevant_cols:

            # print some stat to start with
            print(f"\n--- {relevant_col} ---")
            n_missing_total = df_pivoted[relevant_col].isna().sum()
            n_missing_with_flag = df_pivoted.loc[df_pivoted[col] == 1, relevant_col].isna().sum()
            n_missing_without_flag = df_pivoted.loc[df_pivoted[col] == 0, relevant_col].isna().sum()
            print(f"Missing total: {n_missing_total}")
            print(f"Missing where {col} == 1: {n_missing_with_flag}")
            print(f"Missing where {col} == 0: {n_missing_without_flag}")

            # step 1: mark true missing value
            if n_missing_with_flag > 0:
                isna_cols[f"{relevant_col}_isna"] = ((df_pivoted[col] == 1) & (df_pivoted[relevant_col].isna())).astype(float)

            # step 2: fill column with average
            if defer_imputation:
                deferred_exposure_columns.append(relevant_col)
            else:
                fill_value = df_pivoted.loc[df_pivoted[col] == 1, relevant_col].mean()
                df_pivoted[relevant_col] = df_pivoted[relevant_col].fillna(fill_value)

            # step 3: overwrite to 0.0 if has_med == 0
            df_pivoted.loc[df_pivoted[col]==0, relevant_col] = 0.0

            # print some info after the correction            
            print("After fill:")
            print("  Unique values:", df_pivoted[relevant_col].unique()[:10])
            print(f"  Min, Max: {df_pivoted[relevant_col].min()} , {df_pivoted[relevant_col].max()}")
            print(f"  Count zeros: {(df_pivoted[relevant_col] == 0).sum()}")

            # step 4 (legacy only): drop columns with only 1 value when has_med == 1
            if not defer_imputation:
                if df_pivoted.loc[df_pivoted[col]==1, relevant_col].nunique() <= 1:
                    print(f"  -> Marking {relevant_col} for drop")
                    cols_to_drop.append(relevant_col)
                    if f"{relevant_col}_isna" in isna_cols:
                        cols_to_drop.append(f"{relevant_col}_isna")

    # add back the isna_cols
    print(f"adding these isna columns: {list(isna_cols.keys())}")
    if isna_cols:
        df_pivoted = pd.concat([df_pivoted, pd.DataFrame(isna_cols, index=df_pivoted.index)], axis=1)
    
    # drop the columns with only 1 value
    df_pivoted = df_pivoted.drop(columns=cols_to_drop)
    print(f"df_pivoted shape = {df_pivoted.shape}")

    # ===== some binary column should fill with 0 =======
    cols_todo = [x for x in df_pivoted.columns 
                 if x.startswith('C-Section') \
                 or x.startswith('insurance_') \
                 or x.startswith('c_section_sub_type')]
    print(f"{cols_todo} will be filled with 0")
    for col in cols_todo:
        df_pivoted[col] = df_pivoted[col].fillna(0)
    df_pivoted = df_pivoted.copy()

    # ===== wt columns: add marker then fill with 0; the gap_in_day, fill with mean =======
    for feat in ['wt', 'original_bmi', 'computed_bmi']:
        if (f'{feat}_first_value') not in df_pivoted.columns:
            continue
        cols_todo = [f'{feat}_first_value', f'{feat}_earliest_day',  f'{feat}_last_value', f'{feat}_latest_day',
                     f'{feat}_abs_change', f'{feat}_pct_change', f'{feat}_abs_change_per_month', f'{feat}_pct_change_per_month',
                     f'{feat}_gap_in_days']
        print(f"doing {feat} columns {cols_todo}")
        null_rows = df_pivoted[f'{feat}_first_value'].isna() | df_pivoted[f'{feat}_last_value'].isna()
        df_pivoted[f'{feat}_first_value_isna'] = df_pivoted[f'{feat}_first_value'].isna().astype(float)
        df_pivoted[f'{feat}_last_value_isna'] = df_pivoted[f'{feat}_last_value'].isna().astype(float)
        df_pivoted.loc[df_pivoted[f'{feat}_first_value'].isna(), f'{feat}_earliest_day'] = 365.0
        df_pivoted.loc[df_pivoted[f'{feat}_last_value'].isna(), f'{feat}_latest_day'] = 365.0
        df_pivoted[f'{feat}_first_value'] = df_pivoted[f'{feat}_first_value'].fillna(0)
        df_pivoted[f'{feat}_last_value'] = df_pivoted[f'{feat}_last_value'].fillna(0)
        df_pivoted.loc[null_rows, [f'{feat}_abs_change', f'{feat}_pct_change', 
                                   f'{feat}_abs_change_per_month', f'{feat}_pct_change_per_month']] = 0.0
        if not defer_imputation:
            fill_value = df_pivoted.loc[ (df_pivoted[f'{feat}_first_value_isna'] == 0) & (df_pivoted[f'{feat}_first_value_isna'] == 0),
                                        [f'{feat}_gap_in_days']].mean()
            df_pivoted[f'{feat}_gap_in_days'] = df_pivoted[f'{feat}_gap_in_days'].fillna(fill_value)   

    # ====  bp columns: when count = 0, fill std as 0, freq as 0, other stats mean; when count = 1, fill std as 0, others should be fine
    for prefix in ['all', 'before_delivery', 'after_delivery']:
        count_col = f'bp_{prefix}_count_value'
        if count_col not in df_pivoted.columns:
            continue
        idx = df_pivoted[count_col].isna() | (df_pivoted[count_col] == 0)
        print(f'fixing bp values for {prefix}, total rows = {idx.sum()}')
        idx1 = (df_pivoted[count_col] == 1)
        df_pivoted.loc[idx, count_col] = 0
        for feat in ['systolic', 'diastolic', 'computed_map']:
            col = f'{feat}_{prefix}_std_value'
            df_pivoted.loc[idx, col] = 0.0
            df_pivoted.loc[idx1, col] = 0.0
            for stat in ['mean', 'min', 'max']:
                col = f'{feat}_{prefix}_{stat}_value'
                if defer_imputation:
                    fill_value = np.nan
                else:
                    fill_value = df_pivoted.loc[~idx, col].mean()
                df_pivoted.loc[idx, col] = fill_value
            if prefix == 'all':
                freq_unit = 'week'
            else:
                freq_unit = 'minute'
        col = f'bp_{prefix}_count_per_{freq_unit}_value'
        df_pivoted.loc[idx, col] = 0.0
    
    # ==== dx columns: for both has_dx and count, can both fill with 0
    cols_todo = [x for x in df_pivoted.columns
                 if x.endswith('_has_dx')
                 or x.endswith('_dx_count')
                 or x.endswith('_has_ccsr_category')
                 or x.endswith('_ccsr_category_count')
                 or x.endswith('_has_elixhauser_category')
                 or x.endswith('_elixhauser_category_count')]
    print(f"{cols_todo} will be filled with 0")
    for col in cols_todo:
        if defer_imputation and col in deferred_exposure_columns:
            continue
        df_pivoted[col] = df_pivoted[col].fillna(0)

    # === enc count columns: fill with 0
    cols_todo = [x for x in df_pivoted.columns
                 if x.endswith('_during_pregnancy_count')]
    print(f"{cols_todo} will be filled with 0")
    for col in cols_todo:
        df_pivoted[col] = df_pivoted[col].fillna(0)

    # === parity columns fill with 0
    if 'parity' in df_pivoted.columns:
        print(f"parity will be filled with 0 and add a marker")
        df_pivoted['parity_isna'] = np.where(df_pivoted['parity'].isna(), 1, 0)
        df_pivoted['parity'] = df_pivoted['parity'].fillna(0)

    # === delivery minute fill with mean and add isna
    cols_todo = ['minute_from_admission_to_delivery',
                'minute_from_delivery_to_discharge',
                'minute_membrane_ruptured_to_delivery',
                'minute_second_stage_labor']
    print(f"{cols_todo} will be filled with mean and add a marker")
    for col in cols_todo:
        if col not in df_pivoted.columns:  continue
        df_pivoted[f"{col}_isna"] = df_pivoted[col].isna().astype(float)
        if not defer_imputation:
            df_pivoted[col] = df_pivoted[col].fillna(df_pivoted[col].mean())
    df_pivoted = df_pivoted.copy()

    # === facility locations ====
    cols_to_drop = []
    cols_todo = [x for x in df_pivoted.columns if x.startswith('facility_location')]
    print(f"{cols_todo} will be fill with 0")
    for col in cols_todo:
        if df_pivoted[col].sum() <= 10:
            cols_to_drop.append(col)
        df_pivoted[col] = df_pivoted[col].fillna(0)
    print(f"{cols_to_drop} will be drop")
    df_pivoted = df_pivoted.drop(columns=cols_to_drop)

    # === ebl is actually no null value ====

    # === smoking ====
    cols_todo = ['smoking', 'tobacco']
    print(f"{cols_todo} will be filled with 0 and add a marker")
    for col in cols_todo:
        if col not in df_pivoted:  continue
        df_pivoted[f"{col}_isna"] = df_pivoted[col].isna().astype(float)
        df_pivoted[col] = df_pivoted[col].fillna(0)

    # === or timings ======
    # for proc name, fill with 0
    cols_todo = [x for x in df_pivoted.columns if x.startswith('or_timings_proc_name_')]
    print(f"{cols_todo} will be filled with 0")
    df_pivoted[cols_todo] = df_pivoted[cols_todo].fillna(0)
    # for other timings, fill with 0 and add a flag
    cols_todo = [x for x in df_pivoted.columns if x.startswith('or_timings_') and 'proc_name' not in x]
    print(f"{cols_todo} will be filled with 0 and add a marker")
    for col in cols_todo:
        df_pivoted[f"{col}_isna"] = df_pivoted[col].isna().astype(float)
        df_pivoted[col] = df_pivoted[col].fillna(0)

    # === glucose ====
    # for high gluecose count, fill with 0, otherwise fill with mean, all add flag
    cols_todo = ['max_a1c', 'max_glucose', 'mean_a1c', 'mean_glucose', 'count_high_glucose_1','count_high_glucose_2']
    print(f'{cols_todo} will be filled with 0 or mean and add a marker')
    for col in cols_todo:
        df_pivoted[f"{col}_isna"] = df_pivoted[col].isna().astype(float)
        if col.startswith('count'):
            fill_value = 0
        elif defer_imputation:
            continue
        else:
            fill_value = df_pivoted[col].mean()
        df_pivoted[col] = df_pivoted[col].fillna(fill_value)
    


    return df_pivoted
