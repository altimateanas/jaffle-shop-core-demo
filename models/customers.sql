{% set payment_methods = var('payment_methods') %}

with customers as (

    select * from {{ ref('stg_customers') }}

),

orders as (

    select * from {{ ref('stg_orders') }}

),

payments as (

    select * from {{ ref('stg_payments') }}

),

order_payments as (

    select * from {{ ref('orders') }}

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

first_order_payments as (

    select
        order_payments.customer_id,
        order_payments.order_id,

        {% for payment_method in payment_methods -%}
        case when order_payments.{{ payment_method }}_amount > 0 then 1 else 0 end as used_{{ payment_method }},
        {% endfor -%}

        row_number() over (
            partition by order_payments.customer_id
            order by order_payments.order_date asc, order_payments.order_id asc
        ) as order_rank

    from order_payments

),

customer_first_order_channel as (

    select
        customer_id,

        case
            when (
                {% for payment_method in payment_methods -%}
                used_{{ payment_method }}{{ " + " if not loop.last }}
                {% endfor -%}
            ) > 1 then 'mixed'
            {% for payment_method in payment_methods -%}
            when used_{{ payment_method }} = 1 then '{{ payment_method }}'
            {% endfor -%}
            else null
        end as first_order_channel

    from first_order_payments

    where order_rank = 1

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
        customer_first_order_channel.first_order_channel

    from customers

    left join customer_orders
        on customers.customer_id = customer_orders.customer_id

    left join customer_payments
        on  customers.customer_id = customer_payments.customer_id

    left join customer_first_order_channel
        on customers.customer_id = customer_first_order_channel.customer_id

)

select * from final
