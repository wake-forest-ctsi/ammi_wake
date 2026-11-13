"""
Fold-fitted imputation and deterministic SSI feature filtering.

Place ClinicalImputer inside every model/CV pipeline. Fit learns imputation
statistics using only the current training partition. Transform applies
those statistics to validation/test rows, then calls feature_filter() so
diagnosis aggregation (e.g. Z-code counts) occurs after imputation.
"""

from contextlib import redirect_stdout
from io import StringIO

import numpy as np
import pandas as pd
from sklearn.base import BaseEstimator, TransformerMixin
from sklearn.utils.validation import check_is_fitted

from ssi.feature_filter import feature_filter

EXPOSURE_FLAG_SUFFIXES = (
    "_has_rx",
    "_has_dx",
    "_has_cmqcc_category",
    "_has_ccsr_category",
    "_has_elixhauser_category",
    "_has_med",
    "_has_medadmin_ingredient",
)

BMI_FEATURE_PREFIXES = ("wt", "original_bmi", "computed_bmi")
DELIVERY_TIMING_COLUMNS = (
    "minute_from_admission_to_delivery",
    "minute_from_delivery_to_discharge",
    "minute_membrane_ruptured_to_delivery",
    "minute_second_stage_labor",
)
GLUCOSE_MEAN_COLUMNS = (
    "max_a1c",
    "max_glucose",
    "mean_a1c",
    "mean_glucose",
)


def _get_exposure_flags(columns):
    return [
        column
        for column in columns
        if any(column.endswith(suffix) for suffix in EXPOSURE_FLAG_SUFFIXES)
    ]


def _get_exposure_associations(columns):
    """
    Reproduce the legacy prefix association, excluding generated _isna
    indicators (the old preprocess loop created those only after mapping).
    """
    columns = list(columns)
    flags = _get_exposure_flags(columns)
    associations = []

    for flag in flags:
        code = flag[: flag.index("_has")]
        relevant = [
            candidate
            for candidate in columns
            if candidate.startswith(code)
            and candidate not in flags
            and not candidate.endswith("_isna")
        ]
        associations.extend((flag, candidate) for candidate in relevant)

    return associations


class ClinicalImputer(BaseEstimator, TransformerMixin):
    """
    Apply the original SSI imputation rules using training-partition values.

    Parameters are retained for compatibility with the existing notebooks.
    `columns`, when supplied, selects output columns after feature_filter().
    """

    def __init__(self, skip_medadmin_ingredient=True, columns=None):
        self.skip_medadmin_ingredient = skip_medadmin_ingredient
        self.columns = columns

    @staticmethod
    def _validate_frame(X):
        if not isinstance(X, pd.DataFrame):
            raise TypeError(
                "ClinicalImputer expects a pandas DataFrame so feature names "
                "and the original prefix-based clinical rules can be preserved."
            )
        if not X.columns.is_unique:
            raise ValueError("SSI predictor column names must be unique.")
        return X.astype(float).copy()

    def _filter(self, X):
        # feature_filter prints the list of dropped columns.
        with redirect_stdout(StringIO()):
            filtered = feature_filter(
                X.copy(),
                skip_medadmin_ingredient=self.skip_medadmin_ingredient,
            )
        return filtered.astype(float)

    @staticmethod
    def _mean_or_nan(values):
        value = values.mean()
        return float(value) if pd.notna(value) else np.nan

    def _apply_exposure_operations(self, X):
        X = X.copy()
        for flag, column, fill_value in self.exposure_operations_:
            if flag not in X.columns or column not in X.columns:
                raise ValueError(
                    f"Fitted exposure mapping requires {flag!r} and {column!r}."
                )
            if pd.notna(fill_value):
                X[column] = X[column].fillna(fill_value)
            X.loc[X[flag].eq(0), column] = 0.0
        return X

    def _apply_special_imputation(self, X):
        X = X.copy()

        # Weight/BMI gap-in-days: reproduce the original eligibility rule.
        # The legacy expression checked first_value_isna == 0 twice; retain
        # that exact criterion to avoid silently changing the feature meaning.
        for column, fill_value in self.bmi_gap_fill_values_.items():
            if pd.notna(fill_value):
                X[column] = X[column].fillna(fill_value)

        # BP mean/min/max values for rows with no measurements are imputed
        # using the mean among training rows with count > 0. The fixed-zero
        # rules for count, standard deviation, and frequency remain in
        # preprocess.py.
        for column, count_column, fill_value in self.bp_fill_rules_:
            if column not in X.columns or count_column not in X.columns:
                continue
            no_measurements = (
                X[count_column].isna() | X[count_column].eq(0)
            )
            if pd.notna(fill_value):
                X.loc[no_measurements, column] = (
                    X.loc[no_measurements, column].fillna(fill_value)
                )

        # Delivery intervals and continuous glucose/A1c values used ordinary
        # cohort means in the old preprocessing; use training-fold means now.
        for column, fill_value in self.simple_fill_values_.items():
            if column in X.columns and pd.notna(fill_value):
                X[column] = X[column].fillna(fill_value)

        # The previous ClinicalImputer also supplied a general training-mean
        # fallback for any residual numeric missingness. Keep that behavior,
        # but estimate every fallback from this fit's training rows.
        X = X.fillna(self.fill_values_)
        return X

    def fit(self, X, y=None):
        X = self._validate_frame(X)

        self.feature_names_in_ = X.columns.to_numpy(copy=True)
        self.n_features_in_ = len(self.feature_names_in_)

        working = X.loc[:, self.feature_names_in_].copy()
        exposure_flags = _get_exposure_flags(working.columns)
        if exposure_flags:
            working[exposure_flags] = working[exposure_flags].fillna(0.0)

        # Learn conditional means in the same sequential flag/column order
        # used by the original preprocessing code. This also preserves the
        # legacy behavior if two exposure prefixes overlap.
        self.exposure_operations_ = []

        for flag, column in _get_exposure_associations(working.columns):
            exposed = working[flag].eq(1)
            unexposed = working[flag].eq(0)
            fill_value = self._mean_or_nan(working.loc[exposed, column])

            self.exposure_operations_.append(
                (flag, column, fill_value)
            )

            if pd.notna(fill_value):
                working[column] = working[column].fillna(fill_value)
            working.loc[unexposed, column] = 0.0

        # Fit weight/BMI gap means using the same eligible subset as the
        # original preprocessing. The marker is generated in preprocess.py.
        self.bmi_gap_fill_values_ = {}
        for prefix in BMI_FEATURE_PREFIXES:
            column = f"{prefix}_gap_in_days"
            if column not in working.columns:
                continue
            marker = f"{prefix}_first_value_isna"
            if marker in working.columns:
                eligible = working[marker].eq(0)
            else:
                eligible = working[column].notna()
            self.bmi_gap_fill_values_[column] = self._mean_or_nan(
                working.loc[eligible, column]
            )
            fill_value = self.bmi_gap_fill_values_[column]
            if pd.notna(fill_value):
                working[column] = working[column].fillna(fill_value)

        # Fit BP means for all three periods and all three measures, matching
        # preprocess.py's no-measurement rule. feature_filter() later retains
        # only the selected BP predictors.
        self.bp_fill_rules_ = []
        for prefix in ("all", "before_delivery", "after_delivery"):
            count_column = f"bp_{prefix}_count_value"
            if count_column not in working.columns:
                continue
            measured = working[count_column].gt(0)

            for measure in ("systolic", "diastolic", "computed_map"):
                for stat in ("mean", "min", "max"):
                    column = f"{measure}_{prefix}_{stat}_value"
                    if column not in working.columns:
                        continue
                    fill_value = self._mean_or_nan(
                        working.loc[measured, column]
                    )
                    self.bp_fill_rules_.append(
                        (column, count_column, fill_value)
                    )
                    no_measurements = ~measured
                    if pd.notna(fill_value):
                        working.loc[no_measurements, column] = (
                            working.loc[no_measurements, column].fillna(
                                fill_value
                            )
                        )

        # Ordinary-mean features explicitly identified in preprocess.py.
        self.simple_fill_values_ = {}
        for column in DELIVERY_TIMING_COLUMNS + GLUCOSE_MEAN_COLUMNS:
            if column not in working.columns:
                continue
            fill_value = self._mean_or_nan(working[column])
            self.simple_fill_values_[column] = fill_value
            if pd.notna(fill_value):
                working[column] = working[column].fillna(fill_value)

        # Preserve the current imputer's safety-net behavior, now learned
        # exclusively from this training partition after the special rules.
        raw_fill_values = working.mean()
        self.fallback_columns_ = raw_fill_values.index[
            raw_fill_values.isna()
        ].tolist()
        self.fill_values_ = raw_fill_values.fillna(0.0)
        working = working.fillna(self.fill_values_)

        # Feature filtering/aggregation must happen after imputation. In
        # particular, the Z-code dx-count aggregation must not sum NaNs that
        # should first have received exposure-conditional training means.
        filtered = self._filter(working)
        self.filtered_columns_ = filtered.columns.to_numpy(copy=True)

        if self.columns is None:
            output_columns = list(self.filtered_columns_)
        else:
            output_columns = (
                [self.columns]
                if isinstance(self.columns, str)
                else list(self.columns)
            )
            missing = [
                column for column in output_columns
                if column not in filtered.columns
            ]
            if missing:
                raise ValueError(
                    "Requested ClinicalImputer output columns are absent "
                    f"after SSI feature filtering: {missing}"
                )

        self.feature_names_out_ = np.asarray(output_columns, dtype=object)
        self.n_features_out_ = len(self.feature_names_out_)
        return self

    def transform(self, X):
        check_is_fitted(
            self,
            attributes=[
                "feature_names_in_",
                "exposure_operations_",
                "fill_values_",
                "filtered_columns_",
                "feature_names_out_",
            ],
        )
        X = self._validate_frame(X)

        if set(X.columns) != set(self.feature_names_in_):
            missing = sorted(set(self.feature_names_in_) - set(X.columns))
            extra = sorted(set(X.columns) - set(self.feature_names_in_))
            raise ValueError(
                "SSI predictor columns differ from the fitted input schema. "
                f"Missing: {missing}; extra: {extra}"
            )

        working = X.loc[:, self.feature_names_in_].copy()
        exposure_flags = _get_exposure_flags(working.columns)
        if exposure_flags:
            working[exposure_flags] = working[exposure_flags].fillna(0.0)

        working = self._apply_exposure_operations(working)
        working = self._apply_special_imputation(working)

        filtered = self._filter(working)
        if not np.array_equal(
            filtered.columns.to_numpy(),
            self.filtered_columns_,
        ):
            raise ValueError(
                "SSI filtered columns differ from the fitted output schema. "
                "Check that preprocessing and feature_filter settings are "
                "identical between training and transform data."
            )

        return filtered.loc[:, self.feature_names_out_]

    def get_feature_names_out(self, input_features=None):
        check_is_fitted(self, "feature_names_out_")
        return self.feature_names_out_.copy()
