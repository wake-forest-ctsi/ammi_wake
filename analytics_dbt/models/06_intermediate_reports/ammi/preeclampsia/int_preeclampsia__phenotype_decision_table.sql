-- this is to reproduce unc's definition

{{ config(materialized='table') }}

{% set date_range_list = (dbt.dateadd('week', 20, 'cohort.estimated_preg_start_date'),
                          dbt.dateadd('day', 90, 'cohort.baby_birth_date')) %}

with cohort as (
    select
        *
    from {{ ref('int_preeclampsia__cohort') }}
),

-- mag-infuse needs to be after delivery
-- should this from med_admin or prescribing?
mag_infuse as (
    select
        cohort.birthid,
        max(case when rx_order_date is not null then 1 else 0 end) as mag_infuse
    from cohort
    left join {{ ref('prescribing') }} a on a.patid = cohort.mother_patid
     and {{ add_time_to_date_macro("a.rx_order_date", "a.rx_order_time") }} between {{ "cohort.baby_birth_date" }} and {{ date_range_list[1] }}
     and raw_rx_med_name like '%MAGNESIUM SULFATE%'
     and rx_route = 'INTRAVENOUS'
    group by cohort.birthid
),

-- pre-eclampsia with severe feature or eclampsia
icd_10_pre_sf as (
    select
        cohort.birthid,
        max(case when dx_date is not null then 1 else 0 end) as pre_sf_or_ecl
    from cohort
    left join {{ ref('diagnosis') }} a on a.patid = cohort.mother_patid
     and a.dx_date between {{ date_range_list[0] }} and {{ date_range_list[1] }}
     and (a.dx like 'O14.1%' or a.dx like 'O14.2%' or a.dx like 'O15%')
    group by cohort.birthid
),

-- pre-eclampsia with chronic hyptertension
icd_10_sipe as (
    select
        cohort.birthid,
        max(case when dx_date is not null then 1 else 0 end) as sipe
    from cohort
    left join {{ ref('diagnosis') }} a on a.patid = cohort.mother_patid
     and a.dx_date between {{ date_range_list[0] }} and {{ date_range_list[1] }}
     and a.dx like 'O11%'
    group by cohort.birthid
),

-- Proteinuria
lab_proteinuria as (
    select
        cohort.birthid,
        max(case when specimen_date is not null then 1 else 0 end) as lab_proteinuria
    from cohort
    left join {{ ref('lab_result_cm') }} a on a.patid = cohort.mother_patid
     and {{ add_time_to_date_macro("a.specimen_date", "a.specimen_time") }}  between {{ date_range_list[0] }} and {{ date_range_list[1] }}
     and (
             (lab_loinc = '2889-4' and -- protein in 24h urine > 300mg
             ((substring(lower(result_unit),1,2)='mg' and result_num >= 300) or 
              (substring(lower(result_unit),1,1)='g' and result_num >= 0.3))) 
          or (lab_loinc = '2890-2' and -- urine protein/creatine (upc) > 0.3
             ((substring(lower(result_unit),1,2)='mg' and result_num >= 300) or
              (substring(lower(result_unit),1,2)='mg' and norm_range_high='<=0.15' and result_num >= 0.3) or
              (substring(lower(result_unit),1,1)='g' and result_num >= 0.3)))
     )
    group by cohort.birthid
),

-- other labs
lab_others as (
    select
        cohort.birthid,
        max(case when specimen_date is not null then 1 else 0 end) as lab_others
    from cohort
    left join {{ ref('lab_result_cm') }} a on a.patid = cohort.mother_patid
     and {{ add_time_to_date_macro("a.specimen_date", "a.specimen_time") }} between {{ date_range_list[0] }} and {{ date_range_list[1] }}
     and (
           (lab_loinc = '1920-8' and result_num >= 66) -- ast >= 66
        or (lab_loinc = '1742-6' and result_num >= 72) -- alt >= 72
        or (lab_loinc = '2160-0' and lower(result_unit) = 'mg/dl' and result_num > 1.1 and result_num < 10) -- ct >1.1, there're too many lab with the same loinc code; there's also unit ml/min not sure what to do
        or (lab_loinc = '777-3' and substring(result_unit,1,2) = '10' and result_num < 100) -- plt < 100
     )
    group by cohort.birthid
),

decision_table as (
    select
        a.birthid,
        a.pre_sf_or_ecl,
        b.mag_infuse,
        c.chronic_hyptertension as chtn_any,
        d.bp_cat as bp_cat_after_20wk,
        e.sipe,
        f.lab_proteinuria,
        g.lab_others,
        c.nobp as npbp_pre20wks,
        d.nobp as nobp_ap
    from icd_10_pre_sf a
    left join mag_infuse b on a.birthid = b.birthid
    left join {{ ref('int_preeclampsia__chronic_hypertension') }} c on a.birthid = c.birthid
    left join {{ ref('int_preeclampsia__bp_cat') }} d on a.birthid = d.birthid
    left join icd_10_sipe e on a.birthid = e.birthid
    left join lab_proteinuria f on a.birthid = f.birthid
    left join lab_others g on a.birthid = g.birthid
)

select * from decision_table

