-- Model 5: Type Casting and Boolean Operations
-- Databricks type casting syntax
{{ config(materialized='table') }}

with payments as (
    select * from {{ ref('stg_payments') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

payment_analysis as (
    select
        p.payment_id,
        p.order_id,
        p.payment_method,
        p.amount,

        -- Databricks: cast with double colon syntax not supported, use CAST function
        cast(p.amount as decimal(10, 2)) as amount_decimal,
        cast(p.payment_id as string) as payment_id_string,
        cast(p.amount as int) as amount_integer,

        -- Databricks: boolean expressions (use true/false lowercase)
        case when p.amount > 100 then true else false end as is_large_payment,

        -- Databricks: boolean operations
        p.amount > 50 and p.payment_method = 'credit_card' as is_large_credit_card,

        -- Databricks: null handling with boolean
        p.amount is not null as has_amount,

        -- Databricks: coalesce
        coalesce(p.amount, 0.0) as amount_with_default,

        -- Databricks: nullif
        nullif(p.payment_method, 'unknown') as valid_payment_method,

        -- Databricks: ifnull (alias for coalesce with 2 args)
        ifnull(p.amount, 0.0) as amount_or_zero,

        -- Databricks: nvl (another alias)
        nvl(p.amount, 0.0) as amount_nvl,

        -- Databricks: try_cast (returns null on failure)
        try_cast(p.payment_method as decimal) as payment_method_as_number,

        -- Databricks: typeof returns data type as string
        typeof(p.amount) as amount_data_type
    from payments p
),

final as (
    select
        pa.*,
        o.customer_id,
        o.order_date,

        -- Databricks: implicit boolean to int conversion
        cast(pa.is_large_payment as int) as is_large_payment_int

    from payment_analysis pa
    left join orders o
        on pa.order_id = o.order_id
)

select * from final
