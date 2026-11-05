select *
from {{ ref('fact_orders') }}
where order_date < '{{ var("start_date") }}'