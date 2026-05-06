-- examine the prevalence rate
select
	avg(cast(pre_sf_or_ecl as float)) as pre_sf_or_ecl_prevalence_rate,
	avg(cast(mag_infuse as float)) as mag_infuse_prevalence_rate,
	avg(cast(sipe as float)) as sipe_prevalence_rate,
	avg(cast(chtn_any as float)) as chtn_prevalence_rate,
	avg(case when pre_sf_or_ecl = 1 or mag_infuse = 1 or sipe = 1 then 1.0 else 0.0 end) as at_least_dx_and_mag_prevalence_rate
from {{ ref('int_preeclampsia__phenotype_decision_table') }}