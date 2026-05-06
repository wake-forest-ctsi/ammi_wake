{{ config(materialized='table') }}

{% set date_range_list = ('cohort.baby_birth_date',
                          dbt.dateadd('week', 8, 'cohort.baby_birth_date')) %}

with cohort as (
    select
        birthid,
        mother_patid,
        baby_birth_date,
        delivery_discharge_date
    from {{ ref('int_ssi__cohort') }}
),

diagnosis_specific as (
    select
        patid,
        dx_date,
        1 as has_dx
    from {{ ref('diagnosis')}}
    where dx like 'O86.0%' or dx like 'T81.4%'
),

diagnosis_less_specific as (
    select
        patid,
        dx_date,
        1 as has_dx
    from {{ ref('diagnosis')}}
    where dx like 'O90.0%' or dx like 'O90.9%' -- O90.0 (disruption of a cesarean delivery incision/wound) and O90.9 (Complication of the puerperium, unspecified)
),

med_admin as (
    select
        patid,
        {{ add_time_to_date_macro('medadmin_start_date', 'medadmin_start_time') }} as medadmin_start_date,
        1 as has_med_admin,
        medadmin_route as route
    from {{ ref('med_admin') }}
    where (lower(medadmin_route) = 'intramuscular' or lower(medadmin_route) = 'intravenous')
      and (medadmin_start_date is not null)
      and (lower(raw_medadmin_med_name) like '%ampicillin%'
       or lower(raw_medadmin_med_name) like '%gentamicin%'
       or lower(raw_medadmin_med_name) like '%clindamycin%'
       or lower(raw_medadmin_med_name) like '%metronidazole%'
       or lower(raw_medadmin_med_name) like '%cefazolin%'
       or lower(raw_medadmin_med_name) like '%unasyn%' -- none at wake site
       or lower(raw_medadmin_med_name) like '%sultamicillin%' -- use generic name also none at wake site
       or lower(raw_medadmin_med_name) like '%zosyn%'
       or lower(raw_medadmin_med_name) like '%keflex%' -- none at wake site
       or lower(raw_medadmin_med_name) like '%bactrim%' -- none at wake site
       or lower(raw_medadmin_med_name) like '%sulfamet%trimethoprim%%' -- spell out bactrim found something
       or lower(raw_medadmin_med_name) like '%amoxicillin%')
),

prescribing as (
    select
        patid,
        {{ add_time_to_date_macro('rx_order_date', 'rx_order_time') }} as rx_order_date,
        1 as has_prescribing,
        rx_route as route
    from {{ ref('prescribing') }}
    where (lower(rx_route) = 'intramuscular' or lower(rx_route) = 'intravenous')
      and (rx_order_date is not null)
      and (lower(raw_rx_med_name) like '%ampicillin%'
       or lower(raw_rx_med_name) like '%gentamicin%'
       or lower(raw_rx_med_name) like '%clindamycin%'
       or lower(raw_rx_med_name) like '%metronidazole%'
       or lower(raw_rx_med_name) like '%cefazolin%'
       or lower(raw_rx_med_name) like '%unasyn%' -- none at wake site
       or lower(raw_rx_med_name) like '%sultamicillin%' -- use generic name also none at wake site
       or lower(raw_rx_med_name) like '%zosyn%'
       or lower(raw_rx_med_name) like '%keflex%' -- none at wake site
       or lower(raw_rx_med_name) like '%bactrim%' -- none at wake site
       or lower(raw_rx_med_name) like '%sulfamet%trimethoprim%%' -- spell out bactrim found something
       or lower(raw_rx_med_name) like '%amoxicillin%')
),

renamed as (
    select
        birthid,
        min(delivery_discharge_date) as delivery_discharge_date,
        max(case when diagnosis_specific.has_dx is null then 0 else 1 end) as has_specific_dx,
        min(diagnosis_specific.dx_date) as earliest_specific_dx_date,
        max(case when diagnosis_less_specific.has_dx is null then 0 else 1 end) as has_less_specific_dx,
        min(diagnosis_less_specific.dx_date) as earliest_less_specific_dx_date,
        max(case when has_med_admin is null then 0 else 1 end) as has_med_admin,
        min(medadmin_start_date) as earliest_medadmin_start_date,
        max(case when has_prescribing is null then 0 else 1 end) as has_prescribing,
        min(rx_order_date) as earliest_rx_order_date
    from cohort
    left join diagnosis_specific on cohort.mother_patid = diagnosis_specific.patid
     and diagnosis_specific.dx_date between {{ date_range_list[0] }} and {{ date_range_list[1] }}
    left join diagnosis_less_specific on cohort.mother_patid = diagnosis_less_specific.patid 
     and diagnosis_less_specific.dx_date between {{ date_range_list[0] }} and {{ date_range_list[1] }}
    left join med_admin on cohort.mother_patid = med_admin.patid
     and medadmin_start_date between {{ date_range_list[0] }} and {{ date_range_list[1] }}
    left join prescribing on cohort.mother_patid = prescribing.patid
     and rx_order_date between {{ date_range_list[0] }} and {{ date_range_list[1] }}
    group by birthid
)

select * from renamed