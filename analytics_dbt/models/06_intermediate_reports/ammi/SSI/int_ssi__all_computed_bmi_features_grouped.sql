{{ config(materialized='table') }}

with computed_bmi_base as (
    select
        birthid,
        cast(computed_bmi as float) as computed_bmi,
        measure_date,
        delivery_admit_date,
        cast(datediff(day, measure_date, delivery_admit_date) as float) as days_before_admission
    from {{ ref('int_ssi__all_vital_features') }}
    where computed_bmi is not null and computed_bmi > 0
),

-- first computed_bmi is straightforward, only filter days >= 60
first_computed_bmi_ranked as (
    select
        *,
        row_number() over (partition by birthid order by measure_date asc) as rn
    from computed_bmi_base
    where days_before_admission >= 60
),

first_computed_bmi_value as (
    select
        birthid,
        computed_bmi,
        days_before_admission
    from first_computed_bmi_ranked
    where rn = 1
),

-- last computed_bmi is tricky, need to first filter, then do row_number
last_computed_bmi_filtered as (
    select
        *
    from computed_bmi_base
    where days_before_admission between 0 and 30
),

last_computed_bmi_ranked as (
    select
        *,
        row_number() over (partition by birthid order by measure_date desc) as rn
    from last_computed_bmi_filtered
),

last_computed_bmi_value as (
    select
        birthid,
        computed_bmi,
        days_before_admission
    from last_computed_bmi_ranked
    where rn = 1
),

-- now get the diff value
diff_value as (
    select
        first_computed_bmi_value.birthid,
        last_computed_bmi_value.computed_bmi - first_computed_bmi_value.computed_bmi as computed_bmi_abs_change,
        (last_computed_bmi_value.computed_bmi - first_computed_bmi_value.computed_bmi) / first_computed_bmi_value.computed_bmi as computed_bmi_pct_change,
        first_computed_bmi_value.days_before_admission - last_computed_bmi_value.days_before_admission as gap_in_days,
        case 
            when 
                (first_computed_bmi_value.days_before_admission - last_computed_bmi_value.days_before_admission) >= 14
            then
                (last_computed_bmi_value.computed_bmi - first_computed_bmi_value.computed_bmi) / (first_computed_bmi_value.days_before_admission - last_computed_bmi_value.days_before_admission) * 30
        end as computed_bmi_abs_change_per_month,
        case
            when
                (first_computed_bmi_value.days_before_admission - last_computed_bmi_value.days_before_admission) >= 14
            then
                (last_computed_bmi_value.computed_bmi - first_computed_bmi_value.computed_bmi) / first_computed_bmi_value.computed_bmi / (first_computed_bmi_value.days_before_admission - last_computed_bmi_value.days_before_admission) * 30
        end as computed_bmi_pct_change_per_month
    from first_computed_bmi_value
    left join last_computed_bmi_value on first_computed_bmi_value.birthid = last_computed_bmi_value.birthid
)

select
    birthid,
    'computed_bmi_first_value' as feature_name,
    computed_bmi as value
from first_computed_bmi_value
where computed_bmi is not null

union all

select
    birthid,
    'computed_bmi_earliest_day' as feature_name,
    days_before_admission as value
from first_computed_bmi_value
where days_before_admission is not null

union all

select
    birthid,
    'computed_bmi_last_value' as feature_name,
    computed_bmi as value
from last_computed_bmi_value
where computed_bmi is not null

union all

select
    birthid,
    'computed_bmi_latest_day' as feature_name,
    days_before_admission as value
from last_computed_bmi_value
where days_before_admission is not null

union all

select
    birthid,
    'computed_bmi_abs_change' as feature_name,
    computed_bmi_abs_change
from diff_value
where computed_bmi_abs_change is not null

union all

select
    birthid,
    'computed_bmi_pct_change' as feature_name,
    computed_bmi_pct_change
from diff_value
where computed_bmi_pct_change is not null

union all

select
    birthid,
    'computed_bmi_abs_change_per_month' as feature_name,
    computed_bmi_abs_change_per_month
from diff_value
where computed_bmi_abs_change_per_month is not null

union all

select
    birthid,
    'computed_bmi_pct_change_per_month' as feature_name,
    computed_bmi_pct_change_per_month
from diff_value
where computed_bmi_pct_change_per_month is not null

union all

select
    birthid,
    'computed_bmi_gap_in_days' as feature_name,
    gap_in_days
from diff_value
where gap_in_days is not null