with customers as (

    select * from {{ ref('stg_customers') }}

),

orders as (

    select * from {{ ref('stg_orders') }}

),

payments as (

    select * from {{ ref('stg_payments') }}

),

customer_orders as (

        select
        customer_id,

        min(order_date) as first_order,
        max(order_date) as most_recent_order,
        count(order_id) as number_of_orders
    from orders

    group by customer_id

),

customer_payments as (

    select
        orders.customer_id,
        sum(amount) as total_amount

    from payments

    left join orders on
         payments.order_id = orders.order_id

    group by orders.customer_id

),

final as (

    select
        customers.customer_id,
        customers.first_name,
        customers.last_name,
        customer_orders.first_order,
        customer_orders.most_recent_order,
        customer_orders.number_of_orders,
        customer_payments.total_amount as customer_lifetime_value,

        -- total_order_value: sum of all payment amounts per customer (0 if no payments/orders)
        coalesce(customer_payments.total_amount, 0) as total_order_value,

        -- average_order_value: avg per order, 0 for customers with no orders, division-by-zero safe
        case
            when coalesce(customer_orders.number_of_orders, 0) = 0 then 0
            else coalesce(customer_payments.total_amount, 0) / customer_orders.number_of_orders
        end as average_order_value,

        -- days_since_last_order: days between most recent order and today, NULL if no orders
        case
            when customer_orders.most_recent_order is null then null
            else datediff('day', customer_orders.most_recent_order, current_date)
        end as days_since_last_order,

        -- customer_lifetime_days: days between first and last order, 0 for single order, NULL for no orders
        case
            when customer_orders.first_order is null then null
            else datediff('day', customer_orders.first_order, customer_orders.most_recent_order)
        end as customer_lifetime_days,

        -- customer_segment: VIP (>=10 orders), Regular (5-9), Occasional (1-4 or 0)
        case
            when coalesce(customer_orders.number_of_orders, 0) >= 10 then 'VIP'
            when coalesce(customer_orders.number_of_orders, 0) >= 5  then 'Regular'
            else 'Occasional'
        end as customer_segment

    from customers

    left join customer_orders
        on customers.customer_id = customer_orders.customer_id

    left join customer_payments
        on  customers.customer_id = customer_payments.customer_id

)

select * from final
