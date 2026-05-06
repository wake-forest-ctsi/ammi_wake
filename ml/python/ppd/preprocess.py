import numpy as np
import pandas as pd

def preprocess (dat, verbose=True):

    # parity has a lot of nan, fill with 0 and mark the nan entry
    dat['parity_isna'] = np.where(dat['parity'].isna(), 1, 0)
    if verbose:
        print(f"parity is NaN {dat['parity_isna'].sum()}; will be filled with 0")
    dat['parity'] = dat['parity'].fillna(0.0)

    # check for nans for require columns
    required_cols = ['mother_age_at_birth', 'mother_height', 'bmi', 'delivery_year', 'smoking',
                     'tobacco', 'target_variable']
    if verbose:
        print(f"number of nan in required columns: {dat[required_cols].isna().sum()}")
    dat.dropna(subset=required_cols, inplace=True)
    print(dat.shape)

    # for earliest_day and latest_day, fill with 732 (max + 1)
    cols_todo = [x for x in dat.columns if x.endswith('_earliest_day') or x.endswith('_latest_day')]
    for col in cols_todo:
        dat[col] = dat[col].fillna(732)

    # the others can fill with 0
    phenotype_cols = ['target_variable', 'has_screened', 'F53_label', 'edinburgh_max', 'phq9_total_max', 'other_dx_code']
    cols_todo = [x for x in dat.columns if x not in phenotype_cols]
    for col in cols_todo:
        dat[col] = dat[col].fillna(0)
