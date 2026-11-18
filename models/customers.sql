{#- Payment methods are derived from the `<method>_amount` columns declared on the
    `orders` model (the same list orders.sql builds them from), not re-hardcoded here. -#}
{%- set payment_methods = [] -%}
{%- if execute -%}
    {%- for column_name in graph.nodes['model.' ~ project_name ~ '.orders'].columns.keys() -%}
        {%- if column_name.lower().endswith('_amount') -%}
            {%- do payment_methods.append(column_name.lower()[:-7]) -%}
        {%- endif -%}
    {%- endfor -%}
    {%- if payment_methods | length == 0 -%}
        {{ exceptions.raise_compiler_error("customers: no *_amount columns found on model 'orders'") }}
    {%- endif -%}
{%- endif -%}

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

first_order_payments as (

    select
        customer_id,

        {% for payment_method in payment_methods -%}
        {{ payment_method }}_amount,
        {% endfor -%}

        {# number of distinct payment methods used on the customer's first order #}
        {% for payment_method in payment_methods -%}
        (case when {{ payment_method }}_amount > 0 then 1 else 0 end) +
        {% endfor -%}
        0 as payment_method_count

    from {{ ref('orders') }}

    -- first order = earliest order_date; order_id breaks ties deterministically
    qualify row_number() over (
        partition by customer_id
        order by order_date, order_id
    ) = 1

),

customer_first_order_channel as (

    select
        customer_id,

        case
            when payment_method_count > 1 then 'mixed'
            {% for payment_method in payment_methods -%}
            when {{ payment_method }}_amount > 0 then '{{ payment_method }}'
            {% endfor -%}
        end as first_order_channel

    from first_order_payments

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
