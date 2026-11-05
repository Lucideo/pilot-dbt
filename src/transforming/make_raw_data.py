import duckdb
duckdb.sql("""
copy (select * from (values
  (1, 1, date '2026-01-05', 'completed'),
  (2, 2, date '2026-01-06', 'completed'),
  (3, 1, date '2026-01-10', 'returned'),
  (4, 3, date '2026-02-01', 'placed'),
  (5, 2, date '2026-02-03', 'completed'),
  (6, 2, date '2026-02-10', 'completed')
) t(order_id, customer_id, order_date, status)) to '~/Documents/project_dbt_pilot/raw_data/orders.parquet'
""")
duckdb.sql("""
copy (select * from (values
  (1, 1, 'credit_card', 1000),
  (2, 2, 'pix',         2500),
  (3, 3, 'credit_card', 1500),
  (4, 4, 'boleto',       800),
  (5, 5, 'pix',         3000),
  (6, 6, 'credit_card', 1300)
) t(payment_id, order_id, payment_method, amount_cents)) to '~/Documents/project_dbt_pilot/raw_data/payments.parquet'
""")