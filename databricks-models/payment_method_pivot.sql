-- Model 6: Pivot Operations
-- Databricks pivot syntax
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
        date_format(o.order_date, 'yyyy-MM') as order_month
    from payments p
    inner join orders o
        on p.order_id = o.order_id
),

-- Databricks: PIVOT syntax
pivoted_payments as (
    select *
    from (
        select
            customer_id,
            payment_method,
            amount
        from payments_with_dates
    )
    pivot (
        sum(amount) as total_amount
        for payment_method in (
            'credit_card' as credit_card,
            'bank_transfer' as bank_transfer,
            'coupon' as coupon,
            'gift_card' as gift_card
        )
    )
),

final as (
    select
        customer_id,
        coalesce(credit_card_total_amount, 0) as credit_card_total,
        coalesce(bank_transfer_total_amount, 0) as bank_transfer_total,
        coalesce(coupon_total_amount, 0) as coupon_total,
        coalesce(gift_card_total_amount, 0) as gift_card_total,

        coalesce(credit_card_total_amount, 0) +
        coalesce(bank_transfer_total_amount, 0) +
        coalesce(coupon_total_amount, 0) +
        coalesce(gift_card_total_amount, 0) as total_amount_all_methods
    from pivoted_payments
)

select * from final
