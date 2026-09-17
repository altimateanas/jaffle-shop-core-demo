{{
    config(
        materialized='table'
    )
}}

-- Consumed by the BI dashboard. Only needs a subset of columns.
with summary as (

    select * from {{ ref('customer_order_summary') }}

)

select
    customer_id,
    first_name,
    last_name,
    number_of_orders,
    customer_lifetime_value,
    tenure_bucket,
    frequency_segment,
    monetary_segment,
    rfm_segment
from summary
