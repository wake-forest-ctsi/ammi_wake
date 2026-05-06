# custom scorer and some helpful functions to calculate CI

import numpy as np
from sklearn.metrics import make_scorer, \
    precision_recall_curve, roc_curve, average_precision_score, roc_auc_score, auc
from scipy.stats import bootstrap
from matplotlib import pyplot as plt
import pandas as pd

def boostrap_ci_agg(x, n_resamples=1000, confidence_level=0.95, return_values=False):
    data = (np.asarray(x),)
    res = bootstrap(data, np.mean, n_resamples=n_resamples,
                   confidence_level=confidence_level, method='percentile')
    ci_lower = res.confidence_interval.low
    ci_higher = res.confidence_interval.high
    if return_values:
        return ci_lower, ci_higher
    else:
        return f"{np.mean(x):.3f} ({ci_lower:.3f}-{ci_higher:.3f})"

def get_interpolated_precision(y_true, y_prob, target_recall=0.8):
    precision, recall, _ = precision_recall_curve(y_true, y_prob)
    return np.interp(target_recall, recall[::-1], precision[::-1])

def plot_nested_cv_with_95ci(results_df):
    fig, ax = plt.subplots(1, 2, figsize=(14, 6))

    # Define common grids for interpolation
    mean_fpr = np.linspace(0, 1, 100)
    mean_recall = np.linspace(0, 1, 100)

    tprs = []
    precisions_list = []
    aucs = []
    aps = []

    for y_true, y_prob in zip(results_df['y_true'], results_df['y_probas']):

        # --- ROC Calculation & Interpolation ---
        fpr, tpr, _ = roc_curve(y_true, y_prob)
        tprs.append(np.interp(mean_fpr, fpr, tpr))
        aucs.append(roc_auc_score(y_true, y_prob))

        # --- PR Calculation & Interpolation ---
        # Note: Using your logic from get_interpolated_precision
        prec, rec, _ = precision_recall_curve(y_true, y_prob)
        precisions_list.append(np.interp(mean_recall, rec[::-1], prec[::-1]))
        aps.append(average_precision_score(y_true, y_prob))

    # bootstrap to get the CI
    tprs = np.array(tprs)  # [N_folds x n_seeds, 100]
    precisions_list = np.array(precisions_list)

    tpr_low, tpr_high = [], []
    for i in range(100):
        low, high = boostrap_ci_agg(tprs[:, i], return_values=True)
        tpr_low.append(low)
        tpr_high.append(high)
    
    prec_low, prec_high = [], []
    for i in range(100):
        low, high = boostrap_ci_agg(precisions_list[:, i], return_values=True)
        prec_low.append(low)
        prec_high.append(high)

    # finally plot the curves
    mean_tpr = np.mean(tprs, axis=0)
    ax[0].plot(mean_fpr, mean_tpr, color='b')
    ax[0].fill_between(mean_fpr, tpr_low, tpr_high, color='grey', alpha=0.2)
    ax[0].plot([0, 1], [0, 1], color='r', linestyle='--')
    ax[0].set_title("ROC Curve (Bootstrap CI of Mean)", fontsize=15)
    ax[0].set_xlabel("False Positive Rate (1 - Specificity)", fontsize=13)
    ax[0].set_ylabel("True Positive Rate (Sensitivity)", fontsize=13)

    mean_prec = np.mean(precisions_list, axis=0)
    ax[1].plot(mean_recall, mean_prec, color='b')
    ax[1].fill_between(mean_recall, prec_low, prec_high, color='grey', alpha=0.2)
    ax[1].set_title("PR Curve (Bootstrap CI of Mean)", fontsize=15)
    ax[1].set_xlabel("Recall", fontsize=13)
    ax[1].set_ylabel("Precision", fontsize=13)

    plt.tight_layout()

    # do a sanity check
    trapz_auc_roc = auc(mean_fpr, mean_tpr)
    trapz_auc_pr = auc(mean_recall, mean_prec)
    print(f"direct estimat from figure roc_auc={trapz_auc_roc} pr_auc={trapz_auc_pr}")

    return fig

scorer_sens_50 = make_scorer(get_interpolated_precision, needs_proba=True, target_recall=0.5)
scorer_sens_80 = make_scorer(get_interpolated_precision, needs_proba=True, target_recall=0.8)
scorer_sens_90 = make_scorer(get_interpolated_precision, needs_proba=True, target_recall=0.9)

