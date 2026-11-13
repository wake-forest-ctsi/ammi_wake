from sklearn.base import BaseEstimator, TransformerMixin, clone
from sklearn.utils.validation import check_is_fitted
from joblib import hash as joblib_hash
import numpy as np
from sklearn.feature_selection import mutual_info_classif

class CachedTopKSelector(BaseEstimator, TransformerMixin):
    '''
      Select top-k features using model.feature_importances_, mutal_info_classif or SHAP values
      This version tries to reduce the selector computation to only once per CV fold 
      Rankings are cached by training data and ranking configuration, independently of k.
    '''
    # global cache for the score
    _global_cache = {}

    def __init__(self, model, method='importance', k=20):
        '''
          model: assume it's a tree based model if method=shap, it needs to have both fit and feature_importances_
          method: either "importance", or "shap" or "information_gain"
          k: number of top features
        '''
        self.model = model
        self.method = method
        self.k = k
        # print(f'being init: {CachedTopKSelector._global_cache.keys()}')
    
    def _cache_key(self, X, y, columns):
        return (
            self.method,
            joblib_hash(self.model),
            columns,
            joblib_hash(np.ascontiguousarray(X)),
            joblib_hash(np.ascontiguousarray(y)),
        )
    
    @classmethod
    def clean_cache(cls):
        cls._global_cache = {}

    def _compute_scores(self, X, y):
        '''
            compute the scores given X, y
        '''
        if self.method == 'importance':
            scores = clone(self.model).fit(X, y).feature_importances_
        
        elif self.method == 'shap':
            import shap

            model = clone(self.model).fit(X, y)
            explainer = shap.TreeExplainer(model, data=X,
                                model_output='probability', feature_perturbation='interventional')
            shap_values = explainer(X, check_additivity=True)
            positive = np.flatnonzero(model.classes_ == 1)
            if len(positive) != 1 or len(model.classes_) != 2:
                raise ValueError('SHAP ranking requires binary labels including class 1.')
            values = shap_values.values
            if values.ndim == 3:
                values = values[:, :, positive.item()]
            scores = np.abs(values).mean(axis=0)
        
        elif self.method == 'information_gain':
            scores = mutual_info_classif(X, y)
        
        else:
            raise ValueError(f"Unknown method: {self.method}")

        return scores

    def fit(self, X, y):
        if not isinstance(self.k, (int, np.integer)) or self.k < 1:
            raise ValueError('k must be a positive integer.')
        columns = tuple(X.columns) if hasattr(X, 'columns') else ()
        X = np.asarray(X)
        y = np.asarray(y)
        self.n_features_in_ = X.shape[1]
        self.feature_names_ = np.asarray(columns or [
            f'x{i}' for i in range(self.n_features_in_)
        ], dtype=object)
        key = self._cache_key(X, y, columns)

        if key in CachedTopKSelector._global_cache:
            scores = CachedTopKSelector._global_cache[key]
        else:
            scores = self._compute_scores(X, y)
            CachedTopKSelector._global_cache[key] = scores
        
        self.indices_ = np.argsort(scores)[-self.k:]
        return self
    
    def transform(self, X):
        check_is_fitted(self, 'indices_')
        X = np.asarray(X)
        if X.shape[1] != self.n_features_in_:
            raise ValueError('Input width differs from the fitted selector.')
        return X[:, self.indices_]

    def get_support(self):
        '''
          this only supports indices=True, which returns the indices only
          NOTE: the order is reversed
        '''
        check_is_fitted(self, 'indices_')
        return self.indices_

    def get_feature_names_out(self, input_features=None):
        indices = self.get_support()
        names = self.feature_names_ if input_features is None else np.asarray(input_features)
        return names[indices]

    
