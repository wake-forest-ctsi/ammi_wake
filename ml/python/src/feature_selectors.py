from sklearn.base import BaseEstimator, TransformerMixin
import hashlib
import numpy as np
import shap
from sklearn.feature_selection import mutual_info_classif
from datetime import datetime

class CachedTopKSelector(BaseEstimator, TransformerMixin):
    '''
      Select top-k features using model.feature_importances_, mutal_info_classif or SHAP values
      This version tries to reduce the selector computation to only once per CV fold 
      Be careful that it uses global_cache so ideally you only have one throughout the script or clean up the cache first
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
    
    def _array_hash(self, a):
        return hashlib.sha1(np.ascontiguousarray(a).view(np.uint8)).hexdigest()

    def _cache_key(self, X, y):
        return (
            self.method,
            self._array_hash(X),
            self._array_hash(y)
        )
    
    @classmethod
    def clean_cache(cls):
        cls._global_cache = {}

    def _compute_scores(self, X, y):
        '''
            compute the scores given X, y
        '''
        print(f"re computing score X shape = {X.shape}, y sum = {y.sum()} {datetime.now()}", flush=True)
        if self.method == 'importance':
            self.model.fit(X, y)
            scores = self.model.feature_importances_
        
        elif self.method == 'shap':
            self.model.fit(X, y)
            print(f"starting shap calculation {datetime.now()}", flush=True)
            explainer = shap.TreeExplainer(self.model, data=X,
                                model_output='probability', feature_perturbation='interventional')
            shap_values = explainer(X, check_additivity=True)
            print("done shap calculation", flush=True)
            tmp = np.abs(shap_values.values[:,:,1])
            scores = np.mean(tmp, axis=0)
        
        elif self.method == 'information_gain':
            scores = mutual_info_classif(X, y)
        
        else:
            raise ValueError(f"Unknown method: {self.method}")

        return scores

    def fit(self, X, y):
        X = np.asarray(X)
        y = np.asarray(y)
        key = self._cache_key(X, y)

        if key in CachedTopKSelector._global_cache:
            scores = CachedTopKSelector._global_cache[key]
        else:
            scores = self._compute_scores(X, y)
            CachedTopKSelector._global_cache[key] = scores
        
        self.indices_ = np.argsort(scores)[-self.k:]
        return self
    
    def transform(self, X):
        X = np.asarray(X)
        return X[:, self.indices_]

    def get_support(self):
        '''
          this only supports indices=True, which returns the indices only
          NOTE: the order is reversed
        '''
        return self.indices_

    
