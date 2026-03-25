-- Model 8: JSON Parsing and Functions
-- Databricks JSON syntax
{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

-- Create mock JSON data for demonstration
orders_with_metadata as (
    select
        o.order_id,
        o.customer_id,
        o.order_date,
        o.status,

        -- Databricks: to_json creates JSON string from struct
        to_json(struct(o.status, o.order_date)) as order_metadata_json,

        -- Databricks: named_struct for creating JSON objects
        to_json(named_struct(
            'order_id', o.order_id,
            'status', o.status,
            'date', o.order_date
        )) as full_order_json,

        -- Create a sample JSON string for parsing
        concat('{"status":"', o.status, '","priority":"high","tags":["online","retail"]}') as sample_json

    from orders o
),

parsed_json as (
    select
        order_id,
        customer_id,
        order_date,
        status,
        order_metadata_json,
        full_order_json,
        sample_json,

        -- Databricks: get_json_object extracts value by path
        get_json_object(sample_json, '$.status') as json_status,
        get_json_object(sample_json, '$.priority') as json_priority,

        -- Databricks: from_json with schema
        from_json(
            sample_json,
            'struct<status:string,priority:string,tags:array<string>>'
        ) as parsed_struct,

        -- Databricks: json_tuple extracts multiple values
        json_tuple(sample_json, 'status', 'priority') as (tuple_status, tuple_priority)

    from orders_with_metadata
),

final as (
    select
        p.*,
        c.first_name,
        c.last_name,

        -- Databricks: access struct fields with dot notation
        p.parsed_struct.status as struct_status,
        p.parsed_struct.priority as struct_priority,

        -- Databricks: array access from JSON
        p.parsed_struct.tags[0] as first_tag

    from parsed_json p
    left join customers c
        on p.customer_id = c.customer_id
)

select * from final
