-- Model 9: Conditional Aggregations and Filter Clause
-- Databricks aggregation syntax
{{ config(materialized='table') }}

with payments as (
    select * from {{ ref('stg_payments') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

payments_with_dates as (
    select
        p.payment_id,
        p.order_id,
        p.payment_method,
        p.amount,
        o.customer_id,
        o.order_date,
        o.status,
        year(o.order_date) as order_year,
        month(o.order_date) as order_month
    from payments p
    inner join orders o
        on p.order_id = o.order_id
),

aggregated_payments as (
    select
        customer_id,
        order_year,
        order_month,

        -- Databricks: basic aggregations
        count(*) as total_payments,
        sum(amount) as total_amount,
        avg(amount) as avg_amount,
        min(amount) as min_amount,
        max(amount) as max_amount,

        -- Databricks: conditional aggregations using CASE
        sum(case when payment_method = 'credit_card' then amount else 0 end) as credit_card_amount,
        sum(case when payment_method = 'bank_transfer' then amount else 0 end) as bank_transfer_amount,
        sum(case when payment_method = 'coupon' then amount else 0 end) as coupon_amount,
        sum(case when payment_method = 'gift_card' then amount else 0 end) as gift_card_amount,

        -- Databricks: count with conditions
        count(case when amount > 100 then 1 end) as large_payment_count,
        count(case when payment_method = 'credit_card' then 1 end) as credit_card_count,

        -- Databricks: FILTER clause (SQL 2003 standard, supported in Databricks)
        sum(amount) filter (where payment_method = 'credit_card') as credit_card_filtered,
        count(*) filter (where amount > 50) as medium_payment_count,

        -- Databricks: percentile_approx (approx percentile)
        percentile_approx(amount, 0.5) as median_amount,
        percentile_approx(amount, 0.25) as p25_amount,
        percentile_approx(amount, 0.75) as p75_amount,

        -- Databricks: stddev and variance
        stddev(amount) as amount_stddev,
        variance(amount) as amount_variance,

        -- Databricks: collect_list in aggregation
        collect_list(payment_method) as all_payment_methods,

        -- Databricks: count distinct
        count(distinct payment_method) as distinct_payment_methods,
        count(distinct order_id) as distinct_orders

    from payments_with_dates
    group by customer_id, order_year, order_month
)

select * from aggregated_payments
