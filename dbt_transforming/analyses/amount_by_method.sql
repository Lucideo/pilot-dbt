select
    p.payment_method,
    sum(o.amount) as amount
from
    {{ ref("fact_orders") }} o
inner join {{ ref("stg_payments") }} p on p.order_id = o.order_id
group by 1
order by 2 desc