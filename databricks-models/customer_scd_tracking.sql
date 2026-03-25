-- Model 7: Delta Lake Specific Features
-- Databricks Delta Lake syntax (needs adaptation for Snowflake)
{{ config(
    materialized='incremental',
    unique_key='customer_id',
    incremental_strategy='merge'
) }}

with source_customers as (
    select * from {{ ref('stg_customers') }}
),

customer_changes as (
    select
        customer_id,
        first_name,
        last_name,

        -- Databricks: current_timestamp for tracking
        current_timestamp() as last_updated_at,

        -- Databricks: monotonically_increasing_id for unique IDs
        monotonically_increasing_id() as change_id,

        -- Databricks: hash for change detection
        hash(first_name, last_name) as customer_hash,

        -- Databricks: md5 returns binary, need to cast
        md5(concat(first_name, last_name)) as customer_md5,

        -- Databricks: sha2 with bit length
        sha2(concat(first_name, last_name), 256) as customer_sha256

    from source_customers
)

select * from customer_changes

{% if is_incremental() %}
    -- Databricks: incremental logic
    -- This would use MERGE in Delta Lake
    where last_updated_at > (select max(last_updated_at) from {{ this }})
{% endif %}
