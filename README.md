# pilot-dbt

A small pilot project I built to learn [dbt](https://docs.getdbt.com/). It runs a tiny orders and payments pipeline on [DuckDB](https://duckdb.org/), so everything stays local with no warehouse or credentials. The data is small on purpose. The goal was to try as many dbt features as possible on a dataset small enough to check by eye.

## What it covers

| dbt feature | Where |
|---|---|
| Sources (external Parquet files) | [models/staging/sources.yml](dbt_transforming/models/staging/sources.yml) |
| Seeds | [seeds/customers.csv](dbt_transforming/seeds/customers.csv) |
| Staging → marts layering | [models/staging/](dbt_transforming/models/staging/), [models/marts/](dbt_transforming/models/marts/) |
| Materializations: `view`, `table`, `ephemeral`, `incremental`, `external` | [dbt_project.yml](dbt_transforming/dbt_project.yml) and model configs |
| Macros | [macros/cents_reais.sql](dbt_transforming/macros/cents_reais.sql) (`cents_to_reais`) |
| Project variables | `start_date` in [dbt_project.yml](dbt_transforming/dbt_project.yml) |
| Generic data tests (`unique`, `not_null`, `accepted_values`, `relationships`) | [models/staging/staging.yml](dbt_transforming/models/staging/staging.yml) |
| Package tests (`dbt_utils.expression_is_true`) | [models/marts/marts.yml](dbt_transforming/models/marts/marts.yml) |
| Singular tests | [tests/assert_no_order_before_start.sql](dbt_transforming/tests/assert_no_order_before_start.sql) |
| Unit tests | `dim_customers_sums_orders` in [marts.yml](dbt_transforming/models/marts/marts.yml) |
| Snapshots (`check` strategy) | [snapshots/customers_snapshot.yml](dbt_transforming/snapshots/customers_snapshot.yml) |
| Analyses | [analyses/amount_by_method.sql](dbt_transforming/analyses/amount_by_method.sql) |
| Tags | `finance` on the mart models |
| Packages | [packages.yml](dbt_transforming/packages.yml) (`dbt_utils`) |

## Data flow

```
raw_data/orders.parquet ──► stg_orders ─────────────────────┐
                                                             ├─► fact_orders (incremental) ─┐
raw_data/payments.parquet ─► stg_payments ─► int_order_payments (ephemeral)                 │
                                                                                            ├─► dim_customers ─► export_customers
seeds/customers.csv ───────► stg_customers ─────────────────────────────────────────────────┘                    (→ Parquet file)
         └──────────────────► customers_snapshot
```

**Staging** (views): light cleanup of each input.
- `stg_orders`: orders from the Parquet source, keeping only those on or after `var('start_date')`.
- `stg_payments`: payments, with `amount_cents` converted to reais through the `cents_to_reais` macro.
- `stg_customers`: customers from the seed, with an added `full_name`.

**Marts** (tables):
- `int_order_payments` (ephemeral): total paid per order. It is inlined as a CTE and never built in the database.
- `fact_orders` (incremental, `unique_key = order_id`): one row per order with the amount paid. Later runs only add orders newer than the latest `order_date` already in the table.
- `dim_customers`: one row per customer with `total_orders` and `lifetime_value`.
- `export_customers` (external): writes `dim_customers` to `output_materialize_external/customers.parquet`.

## Project layout

```
pilot_dbt/
├── pyproject.toml          # Python deps (dbt-core, dbt-duckdb), managed with uv
├── src/transforming/
│   └── make_raw_data.py    # generates the raw Parquet files
├── raw_data/               # orders.parquet, payments.parquet
└── dbt_transforming/       # the dbt project
    ├── dbt_project.yml
    ├── profiles.yml        # DuckDB targets: dev (dev.duckdb) and prod (prod.duckdb)
    ├── models/{staging,marts}/
    ├── seeds/  snapshots/  macros/  tests/  analyses/
    └── output_materialize_external/   # output of the external model
```

## Getting started

Requirements: Python 3.14 and [uv](https://docs.astral.sh/uv/).

```bash
# 1. Install dependencies
uv sync

# 2. Generate the raw Parquet files
uv run python src/transforming/make_raw_data.py

# 3. Move into the dbt project (profiles.yml lives here)
cd dbt_transforming

# 4. Install dbt packages (dbt_utils)
uv run dbt deps

# 5. Load seeds, run models, snapshots and tests, all in dependency order
uv run dbt build
```

> **Note on paths:** `make_raw_data.py` and `sources.yml` use absolute paths (`~/Documents/project_dbt_pilot/raw_data/`). If your clone is somewhere else, change both so they point at your `raw_data/` folder.

### Useful commands

```bash
uv run dbt run --select staging          # build only the staging layer
uv run dbt build --select tag:finance    # build and test only the finance-tagged models
uv run dbt test --select test_type:unit  # run only the unit tests
uv run dbt snapshot                      # record changes to customers in the snapshot
uv run dbt run --full-refresh -s fact_orders   # rebuild the incremental model from scratch
uv run dbt compile -s amount_by_method   # compile the analysis to SQL in target/
uv run dbt run --vars '{start_date: "2026-02-01"}'  # override the start_date variable
uv run dbt run --target prod             # build into prod.duckdb instead of dev.duckdb
uv run dbt docs generate && uv run dbt docs serve   # browse the lineage graph
```

### Looking at the results

```bash
duckdb dev.duckdb "select * from dim_customers"
duckdb -c "select * from 'output_materialize_external/customers.parquet'"
```

## Things I learned

- **Layering:** staging models do one cleanup job per source, and marts handle the business logic. Each layer gets its materialization once in `dbt_project.yml` instead of in every model.
- **`ref()` and `source()`** are what give dbt its dependency graph. With them in place, `dbt build` knows the run order without being told.
- **Ephemeral models** are a good fit for small intermediate steps that don't need their own table.
- **Incremental models** need a filter inside `is_incremental()` and a `unique_key`. Use `--full-refresh` when the logic changes.
- **Tests come in four kinds:** generic (YAML), package (`dbt_utils`), singular (a SQL file that should return no rows) and unit tests (fixed inputs with an expected output, no real data needed).
- **Snapshots** track how mutable data changes over time (SCD Type 2). Edit a row in `customers.csv`, then run `dbt seed` and `dbt snapshot` to see it happen.
- **dbt-duckdb** can read Parquet directly as a source (`external_location`) and write models back out as files (the `external` materialization).
