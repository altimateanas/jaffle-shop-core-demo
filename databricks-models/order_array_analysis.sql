-- Model 3: Array and Struct Operations
-- Databricks array/struct syntax
{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

payments as (
    select * from {{ ref('stg_payments') }}
),

order_payments_aggregated as (
    select
        order_id,
        -- Databricks: collect_list (creates array)
        collect_list(payment_method) as payment_methods_array,

        -- Databricks: collect_set (creates array of unique values)
        collect_set(payment_method) as unique_payment_methods,

        -- Databricks: array aggregation
        collect_list(amount) as amounts_array,

        sum(amount) as total_amount
    from payments
    group by order_id
),

final as (
    select
        o.order_id,
        o.customer_id,
        o.order_date,
        o.status,

        -- Databricks: array access with brackets (0-indexed)
        opa.payment_methods_array[0] as first_payment_method,

        -- Databricks: size function for arrays
        size(opa.payment_methods_array) as payment_count,

        -- Databricks: array_contains
        array_contains(opa.payment_methods_array, 'credit_card') as has_credit_card,

        -- Databricks: array_distinct
        array_distinct(opa.payment_methods_array) as distinct_methods,

        -- Databricks: array_join
        array_join(opa.unique_payment_methods, ', ') as payment_methods_string,

        -- Databricks: struct creation
        struct(o.customer_id, o.order_date, o.status) as order_info,

        opa.total_amount
    from orders o
    left join order_payments_aggregated opa
        on o.order_id = opa.order_id
)

select * from final
