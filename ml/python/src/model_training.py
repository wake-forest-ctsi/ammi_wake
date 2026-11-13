from functools import partial

from sklearn.model_selection import GridSearchCV
from sklearn.metrics import f1_score, roc_auc_score, average_precision_score
from sklearn.model_selection import StratifiedGroupKFold
import numpy as np
import pandas as pd
from sklearn.metrics import precision_recall_curve, make_scorer

def get_interpolated_precision(y_true, y_prob, target_recall=0.8):
    precision, recall, _ = precision_recall_curve(y_true, y_prob)
    return np.interp(target_recall, recall[::-1], precision[::-1])

sense_80 = make_scorer(get_interpolated_precision, response_method='predict_proba', target_recall=0.8)


def select_smallest_k_within_auc_tolerance(cv_results, *, tolerance):
    """Return the best candidate at the smallest k within tolerance of peak CV AUC."""
    if not np.isfinite(tolerance) or tolerance < 0:
        raise ValueError('The AUC tolerance must be finite and nonnegative.')

    auc = np.asarray(cv_results['mean_test_score'], dtype=float)
    valid = np.isfinite(auc)
    if not valid.any():
        raise ValueError('Feature-count selection requires a finite mean CV AUC.')

    k = np.asarray([params['selector__k'] for params in cv_results['params']])
    eligible = np.flatnonzero(valid & (auc >= auc[valid].max() - tolerance))
    smallest = eligible[k[eligible] == k[eligible].min()]
    return int(smallest[np.argmax(auc[smallest])])


def loop_over_selector(
    X,
    y,
    pipeline,
    param_grid,
    groups=None,
    outer_splits=10,
    inner_splits=5,
    scoring='roc_auc',
    random_state=42,
    n_jobs=1
):
    '''
        loop over options for the selector in the pipeline
        assume the pipeline and param_grid contains one and only one selector step 
    '''
    key_sv = [x for x in param_grid.keys() if x.startswith('selector__')][0]
    val_sv = param_grid[key_sv][:]
    outputs = []
    for val in val_sv:
        this_grid = param_grid.copy()
        this_grid[key_sv] = [val]
        metrics = nested_cv_evaluation_feature_selection(X, y, pipeline, this_grid, 
                                                         outer_splits, inner_splits, scoring, groups,
                                                         random_state, n_jobs, return_num_features=True)
        metrics['selector__k'] = val
        outputs.append(metrics)
    return pd.concat(outputs, axis=0).reset_index(drop=True)

def nested_cv_evaluation_feature_selection(
    X,
    y,
    pipeline,
    param_grid,
    outer_splits=10,
    inner_splits=9,
    scoring="roc_auc",
    groups=None,
    random_state=42,
    n_jobs=1,   # since random forest is already paralleled, better to stay with 1 here
    return_num_features=False,
    return_for_curves=False,
    return_inner_scores=False,
    *,
    k_auc_tolerance=None,
    return_test_indices=False,
):
    metrics = {"repeat": [], "outer_fold": [], "f1": [], "roc_auc": [], "ap": [], "best_params": [], 'sens_50': [], 'sens_80': [], 'sens_90': []}
    if return_num_features:
        metrics['number_of_features'] = []
        metrics['selected_features'] = []
    if return_for_curves:
        metrics['y_true'] = []
        metrics['y_probas'] = []
    if return_test_indices:
        metrics['test_indices'] = []
    if return_inner_scores:
        metrics['inner_scores'] = []

    if isinstance(random_state, int):
        random_state = [random_state]
    
    if groups is None:
        groups = pd.Series(np.arange(len(X)))

    for seed in random_state:

        outer_cv = StratifiedGroupKFold(n_splits=outer_splits, shuffle=True, random_state=seed)

        for fold_id, (train_idx, test_idx) in enumerate(outer_cv.split(X, y, groups=groups), 1):
            X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
            y_train, y_test = y.iloc[train_idx], y.iloc[test_idx]

            inner_cv = StratifiedGroupKFold(n_splits=inner_splits, shuffle=True, random_state=seed)
            print("start inner cv")
            best_model, grid = tune_model_with_cv(
                X_train, y_train, groups.iloc[train_idx], pipeline, param_grid,
                inner_cv, scoring, n_jobs, k_auc_tolerance=k_auc_tolerance,
            )
            
            y_pred = best_model.predict(X_test)
            y_prob = best_model.predict_proba(X_test)[:, 1]

            if return_num_features:
                selector = best_model.named_steps["selector"]
                indices = selector.get_support()
                metrics["number_of_features"].append(len(indices))
                if isinstance(X, pd.DataFrame):
                    # Resolve selected positions after filtering/imputation.
                    names = best_model[:-1].get_feature_names_out(X.columns)
                    metrics['selected_features'].append(names.tolist())
                else:
                    metrics['selected_features'].append(indices)
            
            if return_for_curves:
                metrics['y_true'].append(y_test.values)
                metrics['y_probas'].append(y_prob)
            if return_test_indices:
                metrics['test_indices'].append(test_idx)
            if return_inner_scores:
                metrics['inner_scores'].append([
                    {**params, 'mean_inner_score': score}
                    for params, score in zip(
                        grid.cv_results_['params'], grid.cv_results_['mean_test_score']
                    )
                ])

            metrics["repeat"].append(seed)
            metrics["outer_fold"].append(fold_id)
            metrics['sens_50'].append(get_interpolated_precision(y_test, y_prob, target_recall=0.5))
            metrics['sens_80'].append(get_interpolated_precision(y_test, y_prob, target_recall=0.8))
            metrics['sens_90'].append(get_interpolated_precision(y_test, y_prob, target_recall=0.9))
            metrics["f1"].append(f1_score(y_test, y_pred))
            metrics["roc_auc"].append(roc_auc_score(y_test, y_prob))
            metrics["ap"].append(average_precision_score(y_test, y_prob))
            metrics["best_params"].append(grid.best_params_)
            
            print(f"[Repeat {seed}, fold {fold_id}] ROC-AUC={metrics['roc_auc'][-1]:.4f}, "
                  f"best_params={grid.best_params_}", flush=True)

    return pd.DataFrame(metrics)

def tune_model_with_cv(
    X, y, groups, pipeline, param_grid, inner_cv, scoring="roc_auc", n_jobs=1,
    *, k_auc_tolerance=None,
):
    """
    Run hyperparameter tuning using the provided inner CV strategy.
    Returns best estimator and search object.
    """
    refit = True
    if k_auc_tolerance is not None:
        if scoring != 'roc_auc':
            raise ValueError('k_auc_tolerance requires ROC-AUC scoring.')
        refit = partial(select_smallest_k_within_auc_tolerance, tolerance=k_auc_tolerance)

    grid = GridSearchCV(
        estimator=pipeline,
        param_grid=param_grid,
        scoring=scoring,
        cv=inner_cv,
        n_jobs=n_jobs,
        verbose=0,
        refit=refit,
    )
    grid.fit(X, y, groups=groups)
    return grid.best_estimator_, grid
