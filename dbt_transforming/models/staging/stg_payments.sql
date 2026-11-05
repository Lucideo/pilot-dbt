select
    payment_id,
    order_id,
    payment_method,
    {{ cents_to_reais('amount_cents') }} as amount
from
    {{ source('raw_data', 'payments') }}