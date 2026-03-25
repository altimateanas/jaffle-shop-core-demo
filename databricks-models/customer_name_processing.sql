-- Model 2: String Functions
-- Databricks-specific string functions
{{ config(materialized='table') }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

processed_customers as (
    select
        customer_id,
        first_name,
        last_name,

        -- Databricks: concat_ws (concat with separator)
        concat_ws(' ', first_name, last_name) as full_name,

        -- Databricks: upper and lower
        upper(last_name) as last_name_upper,
        lower(first_name) as first_name_lower,

        -- Databricks: substring (1-indexed)
        substring(first_name, 1, 1) as first_initial,

        -- Databricks: length
        length(first_name) as first_name_length,

        -- Databricks: regexp_extract
        regexp_extract(first_name, '^[A-Z][a-z]+', 0) as extracted_first_name,

        -- Databricks: regexp_replace
        regexp_replace(last_name, '[^A-Za-z]', '') as clean_last_name,

        -- Databricks: trim, ltrim, rtrim
        trim(first_name) as trimmed_first_name,

        -- Databricks: lpad and rpad
        lpad(cast(customer_id as string), 10, '0') as padded_customer_id,

        -- Databricks: split function returns array
        split(concat_ws(' ', first_name, last_name), ' ') as name_parts,

        -- Databricks: reverse
        reverse(last_name) as reversed_last_name
    from customers
)

select * from processed_customers
