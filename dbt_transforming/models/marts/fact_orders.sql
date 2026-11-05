{{ config(materialized='incremental', unique_key='order_id') }}

select
    o.order_id,
    o.customer_id,
    o.order_date,
    o.status,
    coalesce(p.amount, 0) as amount
from {{ ref('stg_orders') }} o
left join {{ ref('int_order_payments') }} p using (order_id)

{% if is_incremental() %}
where o.order_date > (select max(order_date) from {{ this }})
{% endif %}