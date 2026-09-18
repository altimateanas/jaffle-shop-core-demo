{{ config(materialized='table') }}

-- Customer-level lifetime rollup used by the weekly marketing dashboard.
-- Reads from `customers` and adds tenure + segment classification on top.

with customers as (

    select * from {{ ref('customers') }}

),

final as (

    select
        customer_id,
        first_name,
        last_name,
        first_order,
        most_recent_order,
        number_of_orders,
        customer_lifetime_value,
        datediff('day', first_order, most_recent_order) as tenure_days,
        case
            when customer_lifetime_value >= 100 then 'vip'
            when customer_lifetime_value >= 50  then 'high_value'
            when customer_lifetime_value >= 20  then 'mid_value'
            else 'low_value'
        end as value_segment

    from customers

)

select * from final
