{{
    config(
        materialized='table'
    )
}}

-- Enriches orders with the customer's segment + lifetime context at time of order.
-- Uses customer_order_summary for the segment columns and stg_orders for order-level facts.
with summary as (

    select * from {{ ref('customer_order_summary') }}

),

orders as (

    select * from {{ ref('stg_orders') }}

)

select
    o.order_id,
    o.customer_id,
    o.order_date,
    o.status,
    s.rfm_segment,
    s.frequency_segment,
    s.monetary_segment,
    s.customer_lifetime_value,
    s.number_of_orders as customer_total_orders
from orders o
left join summary s on o.customer_id = s.customer_id
