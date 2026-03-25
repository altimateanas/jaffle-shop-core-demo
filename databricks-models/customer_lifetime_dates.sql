-- Model 1: Date Functions
-- Databricks-specific date functions that differ in Snowflake
{{ config(materialized='table') }}

with customer_orders as (
    select * from {{ ref('stg_orders') }}
),

customer_metrics as (
    select
        customer_id,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date,

        -- Databricks: date_add function
        date_add(min(order_date), 30) as first_order_plus_30days,

        -- Databricks: datediff (date_part, end, start)
        datediff(day, min(order_date), max(order_date)) as customer_lifetime_days,

        -- Databricks: current_timestamp() with parentheses
        current_timestamp() as calculated_at,

        -- Databricks: date_format
        date_format(min(order_date), 'yyyy-MM') as first_order_month,

        -- Databricks: dayofweek (1 = Sunday)
        dayofweek(min(order_date)) as first_order_day_of_week,

        -- Databricks: last_day
        last_day(max(order_date)) as last_order_month_end,

        count(*) as total_orders
    from customer_orders
    group by customer_id
)

select * from customer_metrics
