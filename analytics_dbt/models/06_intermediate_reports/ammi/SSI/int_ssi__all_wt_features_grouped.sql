{{ config(materialized='table') }}

with wt_base as (
    select
        birthid,
        cast(wt as float) as wt,
        measure_date,
        delivery_admit_date,
        cast(datediff(day, measure_date, delivery_admit_date) as float) as days_before_admission
    from {{ ref('int_ssi__all_vital_features') }}
    where wt is not null and wt > 0
),

-- first wt is straightforward, only filter days >= 60
first_wt_ranked as (
    select
        *,
        row_number() over (partition by birthid order by measure_date asc) as rn
    from wt_base
    where days_before_admission >= 60
),

first_wt_value as (
    select
        birthid,
        wt,
        days_before_admission
    from first_wt_ranked
    where rn = 1
),

-- last wt is tricky, need to first filter, then do row_number
last_wt_filtered as (
    select
        *
    from wt_base
    where days_before_admission between 0 and 30
),

last_wt_ranked as (
    select
        *,
        row_number() over (partition by birthid order by measure_date desc) as rn
    from last_wt_filtered
),

last_wt_value as (
    select
        birthid,
        wt,
        days_before_admission
    from last_wt_ranked
    where rn = 1
),

-- now get the diff value
diff_value as (
    select
        first_wt_value.birthid,
        last_wt_value.wt - first_wt_value.wt as wt_abs_change,
        (last_wt_value.wt - first_wt_value.wt) / first_wt_value.wt as wt_pct_change,
        first_wt_value.days_before_admission - last_wt_value.days_before_admission as gap_in_days,
        case 
            when 
                (first_wt_value.days_before_admission - last_wt_value.days_before_admission) >= 14
            then
                (last_wt_value.wt - first_wt_value.wt) / (first_wt_value.days_before_admission - last_wt_value.days_before_admission) * 30
        end as wt_abs_change_per_month,
        case
            when
                (first_wt_value.days_before_admission - last_wt_value.days_before_admission) >= 14
            then
                (last_wt_value.wt - first_wt_value.wt) / first_wt_value.wt / (first_wt_value.days_before_admission - last_wt_value.days_before_admission) * 30
        end as wt_pct_change_per_month
    from first_wt_value
    left join last_wt_value on first_wt_value.birthid = last_wt_value.birthid
)

select
    birthid,
    'wt_first_value' as feature_name,
    wt as value
from first_wt_value
where wt is not null

union all

select
    birthid,
    'wt_earliest_day' as feature_name,
    days_before_admission as value
from first_wt_value
where days_before_admission is not null

union all

select
    birthid,
    'wt_last_value' as feature_name,
    wt as value
from last_wt_value
where wt is not null

union all

select
    birthid,
    'wt_latest_day' as feature_name,
    days_before_admission as value
from last_wt_value
where days_before_admission is not null

union all

select
    birthid,
    'wt_abs_change' as feature_name,
    wt_abs_change
from diff_value
where wt_abs_change is not null

union all

select
    birthid,
    'wt_pct_change' as feature_name,
    wt_pct_change
from diff_value
where wt_pct_change is not null

union all

select
    birthid,
    'wt_abs_change_per_month' as feature_name,
    wt_abs_change_per_month
from diff_value
where wt_abs_change_per_month is not null

union all

select
    birthid,
    'wt_pct_change_per_month' as feature_name,
    wt_pct_change_per_month
from diff_value
where wt_pct_change_per_month is not null

union all

select
    birthid,
    'wt_gap_in_days' as feature_name,
    gap_in_days
from diff_value
where gap_in_days is not null