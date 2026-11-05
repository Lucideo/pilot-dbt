select
    c.customer_id,
    c.full_name,
    c.city,
    count(o.order_id) as total_orders,
    coalesce(sum(o.amount), 0) as lifetime_value
from {{ ref('stg_customers') }} c
left join {{ ref("fact_orders") }} o using (customer_id)
group by all