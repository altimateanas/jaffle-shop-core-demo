-- Model 10: Complex SQL with CTEs, Subqueries, and Multiple Joins
-- Comprehensive Databricks SQL patterns
{{ config(materialized='table') }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

payments as (
    select * from {{ ref('stg_payments') }}
),

-- Calculate order totals
order_totals as (
    select
        order_id,
        sum(amount) as order_amount,
        count(*) as payment_count,
        collect_list(payment_method) as payment_methods
    from payments
    group by order_id
),

-- Enrich orders with amounts
orders_enriched as (
    select
        o.order_id,
        o.customer_id,
        o.order_date,
        o.status,
        coalesce(ot.order_amount, 0) as order_amount,
        ot.payment_count,
        ot.payment_methods,

        -- Databricks: date functions for time-based analysis
        year(o.order_date) as order_year,
        quarter(o.order_date) as order_quarter,
        month(o.order_date) as order_month,
        dayofweek(o.order_date) as order_day_of_week,

        -- Databricks: time difference from current
        datediff(day, o.order_date, current_date()) as days_since_order
    from orders o
    left join order_totals ot
        on o.order_id = ot.order_id
),

-- Customer-level metrics with window functions
customer_order_metrics as (
    select
        customer_id,
        order_id,
        order_date,
        order_amount,

        -- Running calculations
        row_number() over (partition by customer_id order by order_date) as order_number,
        sum(order_amount) over (partition by customer_id order by order_date rows between unbounded preceding and current row) as cumulative_amount,

        -- Time between orders
        datediff(day,
            lag(order_date) over (partition by customer_id order by order_date),
            order_date
        ) as days_since_last_order,

        -- Average order value (running)
        avg(order_amount) over (partition by customer_id order by order_date rows between unbounded preceding and current row) as running_avg_order_value
    from orders_enriched
),

-- Customer lifetime metrics
customer_lifetime_metrics as (
    select
        customer_id,

        -- Basic aggregations
        count(distinct order_id) as total_orders,
        sum(order_amount) as lifetime_value,
        avg(order_amount) as avg_order_value,
        max(order_amount) as max_order_value,
        min(order_amount) as min_order_value,

        -- Date aggregations
        min(order_date) as first_order_date,
        max(order_date) as last_order_date,
        datediff(day, min(order_date), max(order_date)) as customer_lifetime_days,

        -- Databricks: percentile calculations
        percentile_approx(order_amount, 0.5) as median_order_value,

        -- Databricks: array aggregation
        collect_list(order_id) as all_order_ids,
        size(collect_set(order_year)) as active_years,

        -- Conditional aggregations
        sum(case when order_amount > 100 then 1 else 0 end) as high_value_order_count,
        sum(case when status = 'completed' then order_amount else 0 end) as completed_order_value,

        -- FILTER clause
        count(*) filter (where order_amount > 50) as medium_plus_order_count,
        avg(order_amount) filter (where status = 'completed') as avg_completed_order_value

    from orders_enriched
    group by customer_id
),

-- Subquery: customer segments
customer_segments as (
    select
        customer_id,
        lifetime_value,
        total_orders,

        -- Databricks: ntile for segmentation
        ntile(4) over (order by lifetime_value desc) as value_quartile,

        -- Complex CASE for segmentation
        case
            when lifetime_value >= 1000 then 'VIP'
            when lifetime_value >= 500 then 'High Value'
            when lifetime_value >= 100 then 'Medium Value'
            else 'Low Value'
        end as value_segment,

        case
            when total_orders >= 10 then 'Frequent'
            when total_orders >= 5 then 'Regular'
            when total_orders >= 2 then 'Occasional'
            else 'One-time'
        end as frequency_segment

    from customer_lifetime_metrics
),

-- Final comprehensive view
final as (
    select
        c.customer_id,
        c.first_name,
        c.last_name,

        -- Databricks: concat_ws for full name
        concat_ws(' ', c.first_name, c.last_name) as full_name,

        -- Lifetime metrics
        clm.total_orders,
        clm.lifetime_value,
        clm.avg_order_value,
        clm.median_order_value,
        clm.first_order_date,
        clm.last_order_date,
        clm.customer_lifetime_days,

        -- Segments
        cs.value_segment,
        cs.frequency_segment,
        cs.value_quartile,

        -- Calculated metrics
        case
            when clm.customer_lifetime_days > 0 then
                clm.lifetime_value / clm.customer_lifetime_days
            else 0
        end as daily_value_rate,

        -- Databricks: current timestamp
        current_timestamp() as calculated_at,

        -- Days since last order
        datediff(day, clm.last_order_date, current_date()) as days_since_last_order,

        -- Recency, Frequency, Monetary (RFM) scores
        ntile(5) over (order by datediff(day, clm.last_order_date, current_date())) as recency_score,
        ntile(5) over (order by clm.total_orders desc) as frequency_score,
        ntile(5) over (order by clm.lifetime_value desc) as monetary_score

    from customers c
    inner join customer_lifetime_metrics clm
        on c.customer_id = clm.customer_id
    inner join customer_segments cs
        on c.customer_id = cs.customer_id
)

select * from final
