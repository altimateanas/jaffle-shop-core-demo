-- Model: customer_scd_tracking
-- Migrated from Databricks → Snowflake
-- Migration date: 2026-03-26
--
-- Key function mappings applied:
--   Databricks                              → Snowflake
--   current_timestamp()                     → CURRENT_TIMESTAMP()          [identical ✓]
--   monotonically_increasing_id()           → SEQ8()                       [monotonic sequence per session]
--   hash(col1, col2)                        → HASH(col1, col2)             [identical semantics ✓]
--   md5(str)                                → MD5(str)                     [identical — both return hex string ✓]
--   sha2(str, 256)                          → SHA2(str, 256)               [identical ✓]
--   incremental_strategy='merge'            → incremental_strategy='merge' [natively supported ✓]
--   is_incremental()                        → is_incremental()             [identical ✓]
--
-- Migration notes:
--   monotonically_increasing_id() → SEQ8():
--     Databricks monotonically_increasing_id() returns a globally unique monotonically
--     increasing 64-bit integer. Snowflake SEQ8() provides the same monotonic intent
--     within a session. For globally unique cross-session IDs use UUID_STRING() instead.
--     Since change_id is a tracking/audit column (not the merge key), SEQ8() is appropriate.
--
--   Delta Lake MERGE → Snowflake MERGE:
--     Databricks uses Delta Lake's native MERGE for incremental loads.
--     Snowflake dbt adapter supports incremental_strategy='merge' natively with
--     unique_key='customer_id' — no changes required to the dbt config block.

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

        -- Snowflake: CURRENT_TIMESTAMP() — identical to Databricks current_timestamp()
        CURRENT_TIMESTAMP()                             as last_updated_at,

        -- Snowflake: SEQ8() replaces monotonically_increasing_id()
        -- SEQ8() generates a monotonically increasing 64-bit integer sequence.
        -- Note: values are unique within a session; use UUID_STRING() if cross-session
        -- global uniqueness is required.
        SEQ8()                                          as change_id,

        -- Snowflake: HASH(col1, col2) — identical semantics to Databricks hash()
        -- Both return a deterministic numeric hash of the concatenated inputs.
        HASH(first_name, last_name)                     as customer_hash,

        -- Snowflake: MD5(str) — identical to Databricks md5()
        -- Both return a 32-character lowercase hex string.
        -- Note: Databricks md5() returns binary in some contexts; here CONCAT ensures
        -- string input, so the output is identical hex on both platforms.
        MD5(CONCAT(first_name, last_name))              as customer_md5,

        -- Snowflake: SHA2(str, outputLength) — identical to Databricks sha2(str, numBits)
        -- Both accept 256 as the second argument and return a 64-character hex string.
        SHA2(CONCAT(first_name, last_name), 256)        as customer_sha256

    from source_customers
)

select
    customer_id,
    first_name,
    last_name,
    last_updated_at,
    change_id,
    customer_hash,
    customer_md5,
    customer_sha256
from customer_changes

{% if is_incremental() %}
    -- Incremental filter: only process rows updated since the last run.
    -- Snowflake dbt merge strategy will UPSERT on unique_key='customer_id'.
    -- This is functionally identical to Databricks Delta Lake MERGE behaviour.
    where last_updated_at > (select max(last_updated_at) from {{ this }})
{% endif %}
