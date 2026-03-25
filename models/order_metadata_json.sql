-- Model: order_metadata_json
-- Migrated from Databricks → Snowflake
-- Migration date: 2026-03-25
--
-- Key function mappings applied:
--   Databricks                              → Snowflake
--   to_json(struct(...))                    → TO_VARCHAR(OBJECT_CONSTRUCT(...))
--   to_json(named_struct('k', v, ...))      → TO_VARCHAR(OBJECT_CONSTRUCT('k', v, ...))
--   get_json_object(col, '$.key')           → PARSE_JSON(col):key::STRING
--   from_json(col, 'struct<...>')           → PARSE_JSON(col)  (returns VARIANT)
--   json_tuple(col, 'k1', 'k2') AS (a, b)  → individual PARSE_JSON(col):k1::STRING expressions
--   parsed_struct.field                     → parsed_variant:field::STRING
--   parsed_struct.array_field[0]            → parsed_variant:array_field[0]::STRING

{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

-- Build JSON metadata strings from order fields
orders_with_metadata as (
    select
        o.order_id,
        o.customer_id,
        o.order_date,
        o.status,

        -- Snowflake: OBJECT_CONSTRUCT + TO_VARCHAR replaces to_json(struct(...))
        TO_VARCHAR(OBJECT_CONSTRUCT(
            'status',     o.status,
            'order_date', o.order_date
        )) as order_metadata_json,

        -- Snowflake: OBJECT_CONSTRUCT replaces to_json(named_struct(...))
        TO_VARCHAR(OBJECT_CONSTRUCT(
            'order_id', o.order_id,
            'status',   o.status,
            'date',     o.order_date
        )) as full_order_json,

        -- Sample JSON string for downstream parsing demonstration
        CONCAT(
            '{"status":"', o.status,
            '","priority":"high","tags":["online","retail"]}'
        ) as sample_json

    from orders o
),

-- Parse JSON strings and extract individual fields
parsed_json as (
    select
        order_id,
        customer_id,
        order_date,
        status,
        order_metadata_json,
        full_order_json,
        sample_json,

        -- Snowflake: colon path syntax replaces get_json_object(col, '$.key')
        PARSE_JSON(sample_json):status::STRING    as json_status,
        PARSE_JSON(sample_json):priority::STRING  as json_priority,

        -- Snowflake: PARSE_JSON returns VARIANT (replaces from_json with schema definition)
        -- Access fields via colon path notation: variant:field::TYPE
        PARSE_JSON(sample_json)                   as parsed_variant,

        -- Snowflake: separate column expressions replace Databricks json_tuple(col, 'k1', 'k2') AS (a, b)
        PARSE_JSON(sample_json):status::STRING    as tuple_status,
        PARSE_JSON(sample_json):priority::STRING  as tuple_priority

    from orders_with_metadata
),

final as (
    select
        p.order_id,
        p.customer_id,
        p.order_date,
        p.status,
        p.order_metadata_json,
        p.full_order_json,
        p.sample_json,
        p.json_status,
        p.json_priority,
        p.parsed_variant,
        p.tuple_status,
        p.tuple_priority,
        c.first_name,
        c.last_name,

        -- Snowflake: VARIANT colon path access replaces parsed_struct.field dot notation
        p.parsed_variant:status::STRING    as struct_status,
        p.parsed_variant:priority::STRING  as struct_priority,

        -- Snowflake: array element access on VARIANT (same bracket syntax, but on VARIANT type)
        p.parsed_variant:tags[0]::STRING   as first_tag

    from parsed_json p
    left join customers c
        on p.customer_id = c.customer_id
)

select * from final
