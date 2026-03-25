-- Model 4: Window Functions and Row Operations
-- Databricks window function syntax
{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

payments as (
    select * from {{ ref('stg_payments') }}
),

order_amounts as (
    select
        order_id,
        sum(amount) as order_amount
    from payments
    group by order_id
),

orders_with_amounts as (
    select
        o.order_id,
        o.customer_id,
        o.order_date,
        o.status,
        coalesce(oa.order_amount, 0) as order_amount
    from orders o
    left join order_amounts oa
        on o.order_id = oa.order_id
),

ranked_orders as (
    select
        order_id,
        customer_id,
        order_date,
        status,
        order_amount,

        -- Databricks: row_number
        row_number() over (partition by customer_id order by order_date) as order_sequence,

        -- Databricks: rank and dense_rank
        rank() over (partition by customer_id order by order_amount desc) as amount_rank,
        dense_rank() over (partition by customer_id order by order_amount desc) as amount_dense_rank,

        -- Databricks: lag and lead
        lag(order_date, 1) over (partition by customer_id order by order_date) as previous_order_date,
        lead(order_date, 1) over (partition by customer_id order by order_date) as next_order_date,

        -- Databricks: first_value and last_value
        first_value(order_amount) over (partition by customer_id order by order_date rows between unbounded preceding and unbounded following) as first_order_amount,
        last_value(order_amount) over (partition by customer_id order by order_date rows between unbounded preceding and unbounded following) as last_order_amount,

        -- Databricks: running totals
        sum(order_amount) over (partition by customer_id order by order_date rows between unbounded preceding and current row) as running_total,

        -- Databricks: moving averages
        avg(order_amount) over (partition by customer_id order by order_date rows between 2 preceding and current row) as moving_avg_3orders
    from orders_with_amounts
)

select * from ranked_orders
