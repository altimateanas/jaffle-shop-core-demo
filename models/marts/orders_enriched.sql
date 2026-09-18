{{ config(materialized='table') }}

-- Orders enriched with customer identity + lifetime context.
-- Consumed by the finance MRR review dashboard.

with orders as (

    select * from {{ ref('orders') }}

),

customers as (

    select * from {{ ref('customers') }}

)

select
    orders.order_id,
    orders.customer_id,
    customers.first_name,
    customers.last_name,
    orders.order_date,
    orders.status,
    orders.amount,
    orders.credit_card_amount,
    orders.coupon_amount,
    orders.bank_transfer_amount,
    orders.gift_card_amount,
    customers.customer_lifetime_value

from orders
left join customers
    on orders.customer_id = customers.customer_id
