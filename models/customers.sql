with customers as (

    select
        customer_id,
        first_name,
        last_name
    from {{ ref('stg_customers') }}

),

orders as (

    select
        order_id,
        customer_id,
        order_date
    from {{ ref('stg_orders') }}

),

payments as (

    select
        order_id,
        amount
    from {{ ref('stg_payments') }}

),

customer_orders as (

    select
        customer_id,
        min(order_date) as first_order,
        max(order_date) as most_recent_order,
        count(order_id) as number_of_orders,
        datediff('day', max(order_date), current_date)::integer as days_since_last_order,
        datediff('day', min(order_date), max(order_date))::integer as customer_lifetime_days
    from orders

    group by customer_id

),

customer_payments as (

    select
        orders.customer_id,
        sum(payments.amount) as total_amount

    from orders

    left join payments
        on orders.order_id = payments.order_id

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
        customer_orders.days_since_last_order,
        customer_orders.customer_lifetime_days,
        case
            when customer_payments.total_amount >= 100 then 'high_value'
            when customer_payments.total_amount >= 50 then 'medium_value'
            when customer_payments.total_amount is not null then 'low_value'
        end as customer_segment

    from customers

    left join customer_orders
        on customers.customer_id = customer_orders.customer_id

    left join customer_payments
        on customers.customer_id = customer_payments.customer_id

)

select
    customer_id,
    first_name,
    last_name,
    first_order,
    most_recent_order,
    number_of_orders,
    customer_lifetime_value,
    days_since_last_order,
    customer_lifetime_days,
    customer_segment
from final
