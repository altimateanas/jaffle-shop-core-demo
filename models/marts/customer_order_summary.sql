{{
    config(
        materialized='table'
    )
}}

-- One-stop customer + order + payment rollup.
-- Grew organically over ~6 months. Every new "just one more column" request landed here.
-- Now nobody wants to touch it.

with raw_customers as (

    select * from {{ ref('raw_customers') }}

),

raw_orders as (

    select * from {{ ref('raw_orders') }}

),

raw_payments as (

    select * from {{ ref('raw_payments') }}

),

stg_customers as (

    select * from {{ ref('stg_customers') }}

),

stg_orders as (

    select * from {{ ref('stg_orders') }}

),

stg_payments as (

    select * from {{ ref('stg_payments') }}

),

-- Recompute payment pivot inline. We also compute this in orders.sql
-- but that one uses a jinja loop and someone thought "let's just be explicit here".
order_payment_pivot as (

    select
        order_id,
        sum(case when payment_method = 'credit_card' then amount / 100 else 0 end) as credit_card_amount,
        sum(case when payment_method = 'coupon' then amount / 100 else 0 end) as coupon_amount,
        sum(case when payment_method = 'bank_transfer' then amount / 100 else 0 end) as bank_transfer_amount,
        sum(case when payment_method = 'gift_card' then amount / 100 else 0 end) as gift_card_amount,
        sum(amount / 100) as total_amount,
        count(distinct payment_method) as distinct_payment_methods_used,
        max(case when payment_method = 'credit_card' then 1 else 0 end) as used_credit_card_flag,
        max(case when payment_method = 'coupon' then 1 else 0 end) as used_coupon_flag,
        max(case when payment_method = 'bank_transfer' then 1 else 0 end) as used_bank_transfer_flag,
        max(case when payment_method = 'gift_card' then 1 else 0 end) as used_gift_card_flag
    from raw_payments
    group by order_id

),

-- Big monolithic customer-level aggregation. Mixes recency, frequency,
-- monetary, first-order / second-order lookups, tenure buckets, and channel flags
-- all in one CTE. Self-joins to get "second order date" and "n-th order date".
customer_order_history as (

    select
        o1.user_id as customer_id,
        min(o1.order_date) as first_order_date,
        max(o1.order_date) as most_recent_order_date,
        count(distinct o1.id) as number_of_orders,
        count(distinct case when o1.status = 'completed' then o1.id end) as completed_orders,
        count(distinct case when o1.status = 'returned' then o1.id end) as returned_orders,
        count(distinct case when o1.status = 'return_pending' then o1.id end) as return_pending_orders,
        count(distinct case when o1.status = 'shipped' then o1.id end) as shipped_orders,
        count(distinct case when o1.status = 'placed' then o1.id end) as placed_orders,
        sum(opp.total_amount) as customer_lifetime_value,
        sum(opp.credit_card_amount) as lifetime_credit_card_amount,
        sum(opp.coupon_amount) as lifetime_coupon_amount,
        sum(opp.bank_transfer_amount) as lifetime_bank_transfer_amount,
        sum(opp.gift_card_amount) as lifetime_gift_card_amount,
        max(o2.order_date) as second_order_date,
        datediff('day', min(o1.order_date), max(o1.order_date)) as tenure_days,
        case
            when datediff('day', min(o1.order_date), max(o1.order_date)) < 30 then 'new'
            when datediff('day', min(o1.order_date), max(o1.order_date)) < 90 then 'growing'
            when datediff('day', min(o1.order_date), max(o1.order_date)) < 365 then 'established'
            else 'veteran'
        end as tenure_bucket,
        case
            when count(distinct o1.id) = 1 then 'one_and_done'
            when count(distinct o1.id) between 2 and 4 then 'repeat'
            when count(distinct o1.id) between 5 and 9 then 'loyal'
            else 'super_fan'
        end as frequency_segment,
        case
            when sum(opp.total_amount) < 30 then 'low_value'
            when sum(opp.total_amount) < 60 then 'mid_value'
            when sum(opp.total_amount) < 100 then 'high_value'
            else 'vip'
        end as monetary_segment
    from raw_orders o1
    left join raw_orders o2
        on o1.user_id = o2.user_id
        and o2.order_date > (
            select min(o3.order_date)
            from raw_orders o3
            where o3.user_id = o1.user_id
        )
    left join order_payment_pivot opp
        on o1.id = opp.order_id
    group by o1.user_id

),

-- Yet another join back to raw_orders to grab the *first order's* status
-- and amount. We could have done this in the CTE above but by the time
-- someone needed it, the CTE above was already scary.
first_order_details as (

    select
        o.user_id as customer_id,
        o.status as first_order_status,
        opp.total_amount as first_order_amount,
        opp.credit_card_amount as first_order_credit_card_amount,
        opp.coupon_amount as first_order_coupon_amount
    from raw_orders o
    left join order_payment_pivot opp on o.id = opp.order_id
    where o.order_date = (
        select min(o2.order_date)
        from raw_orders o2
        where o2.user_id = o.user_id
    )

),

-- And another one for the most recent order. Same shape, different filter.
most_recent_order_details as (

    select
        o.user_id as customer_id,
        o.status as most_recent_order_status,
        opp.total_amount as most_recent_order_amount
    from raw_orders o
    left join order_payment_pivot opp on o.id = opp.order_id
    where o.order_date = (
        select max(o2.order_date)
        from raw_orders o2
        where o2.user_id = o.user_id
    )

),

final as (

    select
        c.customer_id,
        c.first_name,
        c.last_name,
        coh.first_order_date,
        coh.most_recent_order_date,
        coh.second_order_date,
        coh.number_of_orders,
        coh.completed_orders,
        coh.returned_orders,
        coh.return_pending_orders,
        coh.shipped_orders,
        coh.placed_orders,
        coh.customer_lifetime_value,
        coh.lifetime_credit_card_amount,
        coh.lifetime_coupon_amount,
        coh.lifetime_bank_transfer_amount,
        coh.lifetime_gift_card_amount,
        coh.tenure_days,
        coh.tenure_bucket,
        coh.frequency_segment,
        coh.monetary_segment,
        fod.first_order_status,
        fod.first_order_amount,
        fod.first_order_credit_card_amount,
        fod.first_order_coupon_amount,
        mrod.most_recent_order_status,
        mrod.most_recent_order_amount,
        case
            when coh.frequency_segment = 'super_fan' and coh.monetary_segment = 'vip' then 'champion'
            when coh.frequency_segment in ('loyal', 'super_fan') and coh.monetary_segment in ('high_value', 'vip') then 'loyal_high_value'
            when coh.frequency_segment = 'one_and_done' and coh.monetary_segment in ('high_value', 'vip') then 'big_spender_one_off'
            when coh.frequency_segment = 'one_and_done' then 'trial'
            when coh.returned_orders > coh.completed_orders then 'at_risk'
            else 'standard'
        end as rfm_segment,
        current_timestamp as _dbt_loaded_at
    from stg_customers c
    left join customer_order_history coh on c.customer_id = coh.customer_id
    left join first_order_details fod on c.customer_id = fod.customer_id
    left join most_recent_order_details mrod on c.customer_id = mrod.customer_id

)

select * from final
