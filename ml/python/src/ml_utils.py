import shap
import pandas as pd
import numpy as np

def get_shap(clf, X, max_display=30):
    explainer = shap.TreeExplainer(clf, data=X,
                                   model_output='probability', feature_perturbation='interventional')
    shap_values = explainer(X, check_additivity=True)
    shap_values.values = shap_values.values[:,:,1]
    shap.plots.beeswarm(shap_values, max_display=max_display)
    return shap_values

def shap_to_df(X, shap_values):
    df = pd.DataFrame({
            'feature': X.columns,
            'shap': np.abs(shap_values.values).mean(axis=0)
         })
    return df