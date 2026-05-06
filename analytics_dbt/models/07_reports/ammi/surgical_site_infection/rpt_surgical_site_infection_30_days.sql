{% set tables = [
    {'description': 'phenotype', 'table': ref('int_ssi__phenotype_30_days')},
    {'description': 'baseline', 'table': ref('int_ssi__baseline_features')},
    {'description': 'encounter_counts', 'table': ref('int_ssi__all_enctype_features_grouped')},
    {'description': 'before_delivery_medadmin_ingredient', 'table': ref('int_ssi__before_delivery_medadmin_ingredient_features_grouped')},
    {'description': 'after_delivery_medadmin_ingredient', 'table': ref('int_ssi__after_delivery_medadmin_ingredient_features_grouped')},
    {'description': 'wt', 'table': ref('int_ssi__all_wt_features_grouped')},
    {'description': 'computed_bmi', 'table': ref('int_ssi__all_computed_bmi_features_grouped')},
    {'description': 'original_bmi', 'table': ref('int_ssi__all_original_bmi_features_grouped')},
    {'description': 'diagnosis', 'table': ref('int_ssi__all_dx_features_grouped')},
    {'description': 'smoking', 'table': ref('int_ssi__all_smoking_features_grouped')},
    {'description': 'ebl', 'table': ref('int_ssi__ebl')},
    {'description': 'all_bp', 'table': ref('int_ssi__all_bp_features_grouped')},
    {'description': 'before_delivery_bp', 'table': ref('int_ssi__before_delivery_bp_features_grouped')},
    {'description': 'after_delivery_bp', 'table': ref('int_ssi__after_delivery_bp_features_grouped')},
    {'description': 'or_timings', 'table': ref('int_ssi__c_section_or_timings')},
    {'description': 'glucose', 'table': ref('int_ssi__glucose')}
]%}

{% for pair in tables %}
select 
    birthid,
    '{{ pair.description }}' as 'description',
    feature_name,
    value as 'feature_value'
from {{ pair.table }}
{% if not loop.last %} union all {% endif %}
{% endfor %}

