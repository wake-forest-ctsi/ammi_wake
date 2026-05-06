{{ config(materialized='table') }}

with original_bmi_base as (
    select
        birthid,
        cast(original_bmi as float) as original_bmi,
        measure_date,
        delivery_admit_date,
        cast(datediff(day, measure_date, delivery_admit_date) as float) as days_before_admission
    from {{ ref('int_ssi__all_vital_features') }}
    where original_bmi is not null and original_bmi > 0
),

-- first original_bmi is straightforward, only filter days >= 60
first_original_bmi_ranked as (
    select
        *,
        row_number() over (partition by birthid order by measure_date asc) as rn
    from original_bmi_base
    where days_before_admission >= 60
),

first_original_bmi_value as (
    select
        birthid,
        original_bmi,
        days_before_admission
    from first_original_bmi_ranked
    where rn = 1
),

-- last original_bmi is tricky, need to first filter, then do row_number
last_original_bmi_filtered as (
    select
        *
    from original_bmi_base
    where days_before_admission between 0 and 30
),

last_original_bmi_ranked as (
    select
        *,
        row_number() over (partition by birthid order by measure_date desc) as rn
    from last_original_bmi_filtered
),

last_original_bmi_value as (
    select
        birthid,
        original_bmi,
        days_before_admission
    from last_original_bmi_ranked
    where rn = 1
),

-- now get the diff value
diff_value as (
    select
        first_original_bmi_value.birthid,
        last_original_bmi_value.original_bmi - first_original_bmi_value.original_bmi as original_bmi_abs_change,
        (last_original_bmi_value.original_bmi - first_original_bmi_value.original_bmi) / first_original_bmi_value.original_bmi as original_bmi_pct_change,
        first_original_bmi_value.days_before_admission - last_original_bmi_value.days_before_admission as gap_in_days,
        case 
            when 
                (first_original_bmi_value.days_before_admission - last_original_bmi_value.days_before_admission) >= 14
            then
                (last_original_bmi_value.original_bmi - first_original_bmi_value.original_bmi) / (first_original_bmi_value.days_before_admission - last_original_bmi_value.days_before_admission) * 30
        end as original_bmi_abs_change_per_month,
        case
            when
                (first_original_bmi_value.days_before_admission - last_original_bmi_value.days_before_admission) >= 14
            then
                (last_original_bmi_value.original_bmi - first_original_bmi_value.original_bmi) / first_original_bmi_value.original_bmi / (first_original_bmi_value.days_before_admission - last_original_bmi_value.days_before_admission) * 30
        end as original_bmi_pct_change_per_month
    from first_original_bmi_value
    left join last_original_bmi_value on first_original_bmi_value.birthid = last_original_bmi_value.birthid
)

select
    birthid,
    'original_bmi_first_value' as feature_name,
    original_bmi as value
from first_original_bmi_value
where original_bmi is not null

union all

select
    birthid,
    'original_bmi_earliest_day' as feature_name,
    days_before_admission as value
from first_original_bmi_value
where days_before_admission is not null

union all

select
    birthid,
    'original_bmi_last_value' as feature_name,
    original_bmi as value
from last_original_bmi_value
where original_bmi is not null

union all

select
    birthid,
    'original_bmi_latest_day' as feature_name,
    days_before_admission as value
from last_original_bmi_value
where days_before_admission is not null

union all

select
    birthid,
    'original_bmi_abs_change' as feature_name,
    original_bmi_abs_change
from diff_value
where original_bmi_abs_change is not null

union all

select
    birthid,
    'original_bmi_pct_change' as feature_name,
    original_bmi_pct_change
from diff_value
where original_bmi_pct_change is not null

union all

select
    birthid,
    'original_bmi_abs_change_per_month' as feature_name,
    original_bmi_abs_change_per_month
from diff_value
where original_bmi_abs_change_per_month is not null

union all

select
    birthid,
    'original_bmi_pct_change_per_month' as feature_name,
    original_bmi_pct_change_per_month
from diff_value
where original_bmi_pct_change_per_month is not null

union all

select
    birthid,
    'original_bmi_gap_in_days' as feature_name,
    gap_in_days
from diff_value
where gap_in_days is not null