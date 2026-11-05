{{ config(materialized='external', location='output_materialize_external/customers.parquet') }}

select * from {{ ref('dim_customers') }}