with raw_or_timing as (
    select 
        *
    from {{ ref('stg_csection__or_timings') }}
),

casted_or_timing as (
    select
        birthid,
        -- mother_encounterid,
        proc_name,

        {{ add_time_to_date_macro('case_req_dt', 'case_req_tm') }} as case_req_datetime,
        {{ add_time_to_date_macro('anes_signoff_dt', 'anes_signoff_tm') }} as anes_signoff_datetime,
        {{ add_time_to_date_macro('anes_close_dt', 'anes_close_tm') }} as anes_close_datetime,
        {{ add_time_to_date_macro('anes_addend_dt', 'anes_addend_tm') }} as anes_addend_datetime,
        {{ add_time_to_date_macro('sched_setup_dt', 'sched_setup_tm') }} as sched_setup_datetime,
        {{ add_time_to_date_macro('anes_epidural_dt', 'anes_epidural_tm') }} as anes_epidural_datetime,
        {{ add_time_to_date_macro('sched_in_room_dt', 'sched_in_room_tm') }} as sched_in_room_datetime,
        {{ add_time_to_date_macro('sched_proc_start_dt', 'sched_proc_start_tm') }} as sched_proc_start_datetime,
        {{ add_time_to_date_macro('sched_proc_comp_dt', 'sched_proc_comp_tm') }} as sched_proc_comp_datetime,
        {{ add_time_to_date_macro('sched_out_room_dt', 'sched_out_room_tm') }} as sched_out_room_datetime,
        {{ add_time_to_date_macro('sched_cleanup_dt', 'sched_cleanup_tm') }} as sched_cleanup_datetime,
        {{ add_time_to_date_macro('fac_disch_dt', 'fac_disch_tm') }} as fac_disch_datetime,
        {{ add_time_to_date_macro('in_preproc_dt', 'in_preproc_tm') }} as in_preproc_datetime,
        {{ add_time_to_date_macro('anes_start_dt', 'anes_start_tm') }} as anes_start_datetime,
        {{ add_time_to_date_macro('preproc_comp_dt', 'preproc_comp_tm') }} as preproc_comp_datetime,
        {{ add_time_to_date_macro('in_room_dt', 'in_room_tm') }} as in_room_datetime,
        {{ add_time_to_date_macro('anes_induct_dt', 'anes_induct_tm') }} as anes_induct_datetime,
        {{ add_time_to_date_macro('anes_ready_dt', 'anes_ready_tm') }} as anes_ready_datetime,
        {{ add_time_to_date_macro('proc_start_dt', 'proc_start_tm') }} as proc_start_datetime,
        {{ add_time_to_date_macro('incision_start_dt', 'incision_start_tm') }} as incision_start_datetime,
        {{ add_time_to_date_macro('proc_comp_dt', 'proc_comp_tm') }} as proc_comp_datetime,
        {{ add_time_to_date_macro('out_room_dt', 'out_room_tm') }} as out_room_datetime,
        {{ add_time_to_date_macro('in_recovery_dt', 'in_recovery_tm') }} as in_recovery_datetime,
        {{ add_time_to_date_macro('anes_stop_dt', 'anes_stop_tm') }} as anes_stop_datetime,
        {{ add_time_to_date_macro('recov_disch_ready_dt', 'recov_disch_ready_tm') }} as recov_disch_ready_datetime,
        {{ add_time_to_date_macro('out_recovery_dt', 'out_recovery_tm') }} as out_recovery_datetime,
        {{ add_time_to_date_macro('in_phase_ii_dt', 'in_phase_ii_tm') }} as in_phase_ii_datetime,
        {{ add_time_to_date_macro('phase_ii_disch_ready_dt', 'phase_ii_disch_ready_tm') }} as phase_ii_disch_ready_datetime,
        {{ add_time_to_date_macro('out_phase_ii_dt', 'out_phase_ii_tm') }} as out_phase_ii_datetime,
        {{ add_time_to_date_macro('anes_emerge_dt', 'anes_emerge_tm') }} as anes_emerge_datetime,
        {{ add_time_to_date_macro('intubation_dt', 'intubation_tm') }} as intubation_datetime,
        {{ add_time_to_date_macro('extubation_dt', 'extubation_tm') }} as extubation_datetime,
        {{ add_time_to_date_macro('service_start_dt', 'service_start_tm') }} as service_start_datetime

    from raw_or_timing
)

select * from casted_or_timing;